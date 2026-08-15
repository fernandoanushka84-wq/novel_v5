import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import 'achievements_screen.dart';
import 'profile_screen.dart';
import 'reading_stats_screen.dart';
import 'support_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.data,
    required this.apiService,
    required this.session,
    required this.onSignOut,
  });

  final AppBootstrap data;
  final ApiService apiService;
  final AuthSession session;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      children: [
        _AccountCard(session: session, onSignOut: onSignOut),
        const SizedBox(height: 10),
        ...data.menuSections.map((section) {
          return _Section(
            section: section,
            onTap: (item) async {
              final routeName = item.route.toLowerCase();
              final label = item.label.toLowerCase();

              if (item.route == 'profile' || routeName.contains('profile')) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(
                      profile: data.profile,
                      apiService: apiService,
                      achievements: data.achievements,
                    ),
                  ),
                );
                return;
              }

              if (routeName.contains('logout') || label.contains('logout')) {
                await onSignOut();
                return;
              }

              if (routeName.contains('achievement') ||
                  label.contains('achievement')) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AchievementsScreen(
                      achievements: data.achievements,
                      profile: data.profile,
                    ),
                  ),
                );
                return;
              }

              if (routeName.contains('stat') ||
                  routeName.contains('reading') ||
                  label.contains('reading stat') ||
                  label.contains('stats')) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReadingStatsScreen(
                      profile: data.profile,
                    ),
                  ),
                );
                return;
              }

              if (routeName.contains('support') ||
                  routeName.contains('help') ||
                  label.contains('support') ||
                  label.contains('request')) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SupportScreen(
                      title: item.label,
                      apiService: apiService,
                    ),
                  ),
                );
                return;
              }

              // Fallback: try achievements / stats by common labels
              if (label.contains('badge') || label.contains('trophy')) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AchievementsScreen(
                      achievements: data.achievements,
                      profile: data.profile,
                    ),
                  ),
                );
                return;
              }

              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _PlaceholderScreen(title: item.label),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.session, required this.onSignOut});

  final AuthSession session;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.brand.withValues(alpha: 0.12),
            backgroundImage:
                session.photoUrl != null && session.photoUrl!.isNotEmpty
                ? NetworkImage(session.photoUrl!)
                : null,
            child: session.photoUrl == null || session.photoUrl!.isEmpty
                ? Text(
                    session.displayName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  session.email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onSignOut, child: const Text('Log out')),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.onTap});

  final MenuSectionModel section;
  final ValueChanged<MenuItemModel> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
            child: Text(
              section.section,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ...section.items.map((item) {
            return ListTile(
              dense: true,
              leading: Icon(_iconFor(item.icon), size: 20, color: AppTheme.ink),
              title: Text(
                item.label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
              ),
              onTap: () => onTap(item),
            );
          }),
        ],
      ),
    );
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'person':
        return Icons.person;
      case 'bar_chart':
        return Icons.bar_chart;
      case 'groups':
        return Icons.groups;
      case 'help':
        return Icons.help_outline;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'notifications':
        return Icons.notifications_none;
      case 'language':
        return Icons.language;
      case 'favorite':
        return Icons.favorite_border;
      case 'auto_awesome':
        return Icons.auto_awesome_outlined;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'cookie':
        return Icons.cookie_outlined;
      case 'description':
        return Icons.description_outlined;
      case 'lock':
        return Icons.lock_outline;
      case 'logout':
        return Icons.logout;
      default:
        return Icons.chevron_right;
    }
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title page is ready.')),
    );
  }
}
