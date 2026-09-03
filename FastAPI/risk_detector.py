import os
import math
import logging
from typing import Optional, Tuple
import numpy as np

from email_service import send_emergency_checkin_email

logger = logging.getLogger("auramind.risk_detector")

_WEIGHTS = None
_TOKENIZER = None
_MODEL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "suicide_risk_bert_model")
_v_erf = np.vectorize(math.erf)


def _layer_norm(x: np.ndarray, gamma: np.ndarray, beta: np.ndarray, eps: float = 1e-12) -> np.ndarray:
    mean = np.mean(x, axis=-1, keepdims=True)
    var = np.var(x, axis=-1, keepdims=True)
    return gamma * (x - mean) / np.sqrt(var + eps) + beta


def _gelu(x: np.ndarray) -> np.ndarray:
    return 0.5 * x * (1.0 + _v_erf(x / math.sqrt(2.0)))


HF_REPO_ID = os.getenv("SUICIDE_RISK_HF_REPO", "nusaibuhh/suicide_risk_bert")


def _get_model_and_tokenizer():
    """
    Lazy-load model weights and tokenizer.
    If local files are missing (e.g. on a cloud deployment like Railway),
    automatically downloads and caches them from Hugging Face Hub ('nusaibuhh/suicide_risk_bert').
    """
    global _WEIGHTS, _TOKENIZER
    if _WEIGHTS is not None and _TOKENIZER is not None:
        return _WEIGHTS, _TOKENIZER

    try:
        from safetensors.numpy import load_file
        import tokenizers

        weights_path = os.path.join(_MODEL_DIR, "model.safetensors")
        tokenizer_path = os.path.join(_MODEL_DIR, "tokenizer.json")

        # 1. Resolve model weights (local or Hugging Face Hub)
        if not os.path.exists(weights_path):
            logger.info("Local weights not found at %s. Downloading from Hugging Face Hub: %s...", weights_path, HF_REPO_ID)
            print(f"[Suicide Risk Detector] Downloading model.safetensors from Hugging Face ({HF_REPO_ID})...")
            from huggingface_hub import hf_hub_download
            weights_path = hf_hub_download(repo_id=HF_REPO_ID, filename="model.safetensors")

        # 2. Resolve tokenizer (local or Hugging Face Hub)
        if not os.path.exists(tokenizer_path):
            logger.info("Local tokenizer not found at %s. Downloading from Hugging Face Hub: %s...", tokenizer_path, HF_REPO_ID)
            print(f"[Suicide Risk Detector] Downloading tokenizer.json from Hugging Face ({HF_REPO_ID})...")
            from huggingface_hub import hf_hub_download
            tokenizer_path = hf_hub_download(repo_id=HF_REPO_ID, filename="tokenizer.json")

        logger.info("Loading suicide_risk_bert weights and tokenizer...")
        _WEIGHTS = load_file(weights_path)
        _TOKENIZER = tokenizers.Tokenizer.from_file(tokenizer_path)
        logger.info("suicide_risk_bert model loaded successfully (NumPy inference engine).")
        print("[Suicide Risk Detector] Model and tokenizer loaded successfully.")
        return _WEIGHTS, _TOKENIZER
    except Exception as exc:
        logger.error("Failed to load suicide_risk_bert model: %s", exc)
        print(f"[Suicide Risk Detector] Error loading model: {exc}")
        return None, None


def classify_suicide_risk(text: str) -> int:
    """
    Classifies the provided text using the fine-tuned BERT model via pure NumPy forward pass.
    Returns:
        1 if suicide/self-harm risk is detected.
        0 if no risk is detected or if an error occurs.
    """
    cleaned = (text or "").strip()
    if not cleaned:
        return 0

    weights, tokenizer = _get_model_and_tokenizer()
    if weights is None or tokenizer is None:
        logger.warning("suicide_risk_bert model unavailable; defaulting to 0.")
        return 0

    try:
        enc = tokenizer.encode(cleaned)
        ids = np.array(enc.ids, dtype=np.int64)
        seq_len = len(ids)
        if seq_len > 512:
            ids = ids[:512]
            seq_len = 512

        pos_ids = np.arange(seq_len, dtype=np.int64)
        type_ids = np.zeros(seq_len, dtype=np.int64)

        # Word, position, token_type embeddings
        w_emb = weights["bert.embeddings.word_embeddings.weight"][ids]
        p_emb = weights["bert.embeddings.position_embeddings.weight"][pos_ids]
        t_emb = weights["bert.embeddings.token_type_embeddings.weight"][type_ids]
        x = w_emb + p_emb + t_emb
        x = _layer_norm(
            x,
            weights["bert.embeddings.LayerNorm.gamma"],
            weights["bert.embeddings.LayerNorm.beta"],
        )

        num_heads = 12
        head_dim = 64

        # 12 Encoder layers
        for i in range(12):
            prefix = f"bert.encoder.layer.{i}"

            # Self-Attention
            q = np.dot(x, weights[f"{prefix}.attention.self.query.weight"].T) + weights[f"{prefix}.attention.self.query.bias"]
            k = np.dot(x, weights[f"{prefix}.attention.self.key.weight"].T) + weights[f"{prefix}.attention.self.key.bias"]
            v = np.dot(x, weights[f"{prefix}.attention.self.value.weight"].T) + weights[f"{prefix}.attention.self.value.bias"]

            q = q.reshape(seq_len, num_heads, head_dim).transpose(1, 0, 2)
            k = k.reshape(seq_len, num_heads, head_dim).transpose(1, 0, 2)
            v = v.reshape(seq_len, num_heads, head_dim).transpose(1, 0, 2)

            scores = np.matmul(q, k.transpose(0, 2, 1)) / math.sqrt(head_dim)
            exp_scores = np.exp(scores - np.max(scores, axis=-1, keepdims=True))
            attn_probs = exp_scores / np.sum(exp_scores, axis=-1, keepdims=True)

            context = np.matmul(attn_probs, v).transpose(1, 0, 2).reshape(seq_len, 768)

            # Attention output dense + LayerNorm
            attn_out = np.dot(context, weights[f"{prefix}.attention.output.dense.weight"].T) + weights[f"{prefix}.attention.output.dense.bias"]
            x = _layer_norm(
                x + attn_out,
                weights[f"{prefix}.attention.output.LayerNorm.gamma"],
                weights[f"{prefix}.attention.output.LayerNorm.beta"],
            )

            # Feed-forward intermediate & output
            inter = _gelu(np.dot(x, weights[f"{prefix}.intermediate.dense.weight"].T) + weights[f"{prefix}.intermediate.dense.bias"])
            out = np.dot(inter, weights[f"{prefix}.output.dense.weight"].T) + weights[f"{prefix}.output.dense.bias"]
            x = _layer_norm(
                x + out,
                weights[f"{prefix}.output.LayerNorm.gamma"],
                weights[f"{prefix}.output.LayerNorm.beta"],
            )

        # Pooler (CLS token at index 0)
        cls_token = x[0]
        pooled = np.tanh(np.dot(cls_token, weights["bert.pooler.dense.weight"].T) + weights["bert.pooler.dense.bias"])

        # Classifier logits
        logits = np.dot(pooled, weights["classifier.weight"].T) + weights["classifier.bias"]
        predicted_class = int(np.argmax(logits))
        return predicted_class

    except Exception as exc:
        logger.error("Inference error during suicide risk classification: %s", exc)
        return 0


def scan_and_alert_emergency_contact(
    text: str,
    user_id: str,
    db_connection_factory=None,
) -> Optional[int]:
    """
    Background worker task:
    1. Classifies the submitted text for suicide risk using the BERT model.
    2. If prediction == 1, checks if the user has an emergency contact email.
    3. If emergency contact email is present, sends a gentle check-in email via Postmark.
    4. The operation is completely silent to the end-user.
    """
    import app as fastapi_app

    if not text or not user_id:
        return None

    try:
        risk_score = classify_suicide_risk(text)
        print(f"[Suicide Risk Scan] User {user_id}: Text analyzed. Risk Score = {risk_score} (1=Risk, 0=No Risk)")
        logger.info("Suicide risk scan for user %s returned: %s", user_id, risk_score)

        if risk_score == 1:
            connect_fn = db_connection_factory or fastapi_app.connect_db_connection
            conn = connect_fn()
            c = conn.cursor()
            c.execute(
                "SELECT name, emergency_contact FROM USERS WHERE id=?",
                (user_id,),
            )
            row = c.fetchone()
            conn.close()

            if row:
                user_name = row[0] or "your friend"
                emergency_contact = (row[1] or "").strip()
                print(f"[Emergency Contact] Retrieved contact for {user_name}: '{emergency_contact}'")
                if emergency_contact and "@" in emergency_contact:
                    print(f"[Emergency Alert] Risk detected! Dispatching email to {emergency_contact}...")
                    send_emergency_checkin_email(
                        to_email=emergency_contact,
                        friend_name=user_name,
                    )
                else:
                    print(f"[Emergency Contact] User {user_id} has no valid emergency contact email configured.")
            else:
                print(f"[Emergency Contact] User {user_id} not found in database.")
        else:
            print(f"[Suicide Risk Scan] No risk detected (Score = 0). No email sent.")
        return risk_score
    except Exception as exc:
        print(f"[Suicide Risk Scan] Error during scan/alert: {exc}")
        logger.error("Error in scan_and_alert_emergency_contact: %s", exc)
        return None
