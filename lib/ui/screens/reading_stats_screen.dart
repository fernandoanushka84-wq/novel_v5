import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';

/// Inkitt-style Reading Stats: summary cards + simple weekly chart.
class ReadingStatsScreen extends StatelessWidget {
  const ReadingStatsScreen({
    super.key,
    required this.profile,
  });

  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    // Synthetic weekly bars for chart (replace with API series when available)
    final week = <double>[0.4, 0.7, 0.55, 0.9, 0.65, 0.35, 0.8];
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Reading Stats'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFF9B59B6),
                  label: 'CHAPTERS READ',
                  value: '${profile.chaptersRead}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.local_fire_department_outlined,
                  color: const Color(0xFFE85D4C),
                  label: 'DAY STREAK',
                  value: '${profile.dayStreak}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statCard(
            icon: Icons.campaign_outlined,
            color: AppTheme.brand,
            label: 'SOCIAL KARMA',
            value: '${profile.socialKarma}',
          ),
          const SizedBox(height: 28),
          const Text(
            'This week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chapters read per day',
            style: TextStyle(fontSize: 12, color: Color(0xFF8A8F98)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(week.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: week[i].clamp(0.08, 1.0),
                              widthFactor: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i == week.length - 1
                                      ? AppTheme.brand
                                      : AppTheme.brand.withValues(alpha: 0.35),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[i],
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A8F98),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Reading lists',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (profile.readingLists.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No reading lists yet',
                  style: TextStyle(color: Color(0xFF8A8F98)),
                ),
              ),
            )
          else
            ...profile.readingLists.map((list) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE8EAED)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.collections_bookmark_outlined,
                      color: AppTheme.brand,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        list.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${list.storyCount} stories',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A8F98),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A8F98),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
