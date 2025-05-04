import 'package:flutter/material.dart';

class SigninWidget extends StatelessWidget {
  const SigninWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildRow('mal-icon.png'),  // MyAnimeList
        const SizedBox(height: 30),
        _buildRow('anilist-icon.png'),  // Anilist
        const SizedBox(height: 30),
        _buildRow('kitsu-icon.png'),  // Kitsu
        const SizedBox(height: 30),
        _buildRow('simkl-icon.png'),  // Simkl
      ],
    );
  }

  Widget _buildRow(String secondImage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleAvatar(
          backgroundImage: AssetImage('assets/images/mwl-black-bg.png'), // Logo DailyAL
          radius: 40,
        ),
        const SizedBox(width: 20),
        CircleAvatar(
          backgroundImage: AssetImage('assets/images/$secondImage'), // Logo dynamique
          radius: 40,
        ),
      ],
    );
  }
}
