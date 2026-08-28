import 'package:flutter/material.dart';

import '../../models/best_self_vision.dart';

class BestSelfHistoryScreen extends StatelessWidget {
  const BestSelfHistoryScreen({super.key, required this.visions});

  final List<BestSelfVision> visions;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFFFEFC),
        appBar: AppBar(
          title: const Text('Your Best Possible Selves'),
          backgroundColor: const Color(0xFFFFFEFC),
          surfaceTintColor: Colors.transparent,
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: visions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final vision = visions[index];
            final date = MaterialLocalizations.of(context)
                .formatMediumDate(vision.createdAt);
            return InkWell(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: .75,
                  builder: (_, controller) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: ListView(
                      controller: controller,
                      children: [
                        Text('${vision.timeline}-year vision', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(date, style: const TextStyle(color: Color(0xFF66736D))),
                        const SizedBox(height: 22),
                        Text(vision.vision, style: const TextStyle(fontSize: 16, height: 1.6)),
                      ],
                    ),
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: index == 0 ? const Color(0xFFF0F6EF) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDCE7DC)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFDDEBDD),
                    child: Icon(index == 0 ? Icons.push_pin : Icons.auto_awesome, color: const Color(0xFF5E8C76)),
                  ),
                  const SizedBox(width: 13),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(index == 0 ? 'Pinned · ${vision.timeline}-year vision' : '${vision.timeline}-year vision', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(vision.vision, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF42524B), height: 1.35)),
                    const SizedBox(height: 7), Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF66736D))),
                  ])),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            );
          },
        ),
      );
}
