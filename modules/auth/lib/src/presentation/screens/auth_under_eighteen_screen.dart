import 'package:flutter/material.dart';
import 'package:core/core.dart';

class AuthUnderEighteenScreen extends StatelessWidget {
  const AuthUnderEighteenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BalsmRoundButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onTap: () => Navigator.of(context).pop(),
                semanticLabel: 'Back',
              ),
              const SizedBox(height: 32),
              const BalsmStepDots(totalSteps: 3, currentStep: 1),
              const SizedBox(height: 24),
              Text(
                'Not available yet',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Balsm is currently available for users 18 and older. '
                'We\'re working on a version for younger users with parental consent.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              BalsmButton(
                label: 'Notify me when available',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
