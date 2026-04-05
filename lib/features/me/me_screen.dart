import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/dopamine_card.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await AuthService.instance.signOut();
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      _MenuItem(
        icon: Icons.favorite_rounded,
        label: 'Interests',
        color: AppColors.primary,
      ),
      _MenuItem(
        icon: Icons.bolt_rounded,
        label: 'Travel Preferences',
        color: AppColors.secondary,
      ),
      _MenuItem(
        icon: Icons.shield_outlined,
        label: 'Safety Settings',
        color: AppColors.accent,
      ),
      _MenuItem(
        icon: Icons.notifications_none_rounded,
        label: 'Notifications',
        color: Colors.blue,
      ),
      _MenuItem(
        icon: Icons.settings_outlined,
        label: 'App Settings',
        color: Colors.grey,
      ),
    ];

    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        final User? user = snapshot.data ?? AuthService.instance.currentUser;
        final String displayName =
            (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!
            : 'WanderJoy Explorer';
        final String email = (user?.email?.trim().isNotEmpty ?? false)
            ? user!.email!
            : 'No email available';

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            140,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
                IconButton.filled(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined),
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Column(
                children: [
                  _ProfileAvatar(user: user),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: const [
                Expanded(
                  child: _ProfileStat(
                    value: '12',
                    label: 'Trips',
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _ProfileStat(
                    value: '45',
                    label: 'Places',
                    color: AppColors.secondary,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _ProfileStat(
                    value: '5.0',
                    label: 'Safety',
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DopamineCard(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(item.icon, color: item.color),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFC7C7C7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _isSigningOut ? null : _handleSignOut,
              icon: _isSigningOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(_isSigningOut ? 'Signing Out...' : 'Log Out'),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final String? photoUrl = user?.photoURL;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.network(
          photoUrl,
          width: 132,
          height: 132,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 64,
        color: AppColors.primary,
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DopamineCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}
