import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

class RxSwiftLogo extends StatelessWidget {
  const RxSwiftLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // ADD THIS
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Rx',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  TextSpan(
                    text: 'Swift',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.logoAccent,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'C A L G A R Y',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                letterSpacing: 3.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}