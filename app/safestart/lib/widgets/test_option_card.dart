import 'package:flutter/material.dart';

import 'custom_card.dart';
import 'primary_button.dart';

class TestOptionCard extends StatelessWidget {
  const TestOptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.assetPath,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String assetPath;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CustomCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1.65,
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              excludeFromSemantics: true,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(description),
        const SizedBox(height: 20),
        PrimaryButton(label: actionLabel, onPressed: onPressed),
      ],
    ),
  );
}
