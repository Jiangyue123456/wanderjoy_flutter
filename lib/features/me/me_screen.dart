import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/dopamine_card.dart';
import '../../shared/widgets/primary_button.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _avatarUrlController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _interestsController = TextEditingController();
  final _bioController = TextEditingController();
  final _safetyRatingController = TextEditingController();

  String _preferredIntensity = 'Medium';
  bool _isSigningOut = false;
  bool _isSaving = false;
  bool _hasHydratedForm = false;
  String? _hydratedProfileId;

  @override
  void dispose() {
    _avatarUrlController.dispose();
    _displayNameController.dispose();
    _ageController.dispose();
    _interestsController.dispose();
    _bioController.dispose();
    _safetyRatingController.dispose();
    super.dispose();
  }

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

  Future<void> _saveProfile(User user, bool profileExists) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final interests = _interestsController.text
        .split(',')
        .map((interest) => interest.trim())
        .where((interest) => interest.isNotEmpty)
        .toList();

    final data = <String, Object?>{
      'avatarUrl': _avatarUrlController.text.trim(),
      'displayName': _displayNameController.text.trim(),
      'age': int.parse(_ageController.text.trim()),
      'interests': interests,
      'bio': _bioController.text.trim(),
      'preferredIntensity': _preferredIntensity,
      'safetyRating': double.parse(_safetyRatingController.text.trim()),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!profileExists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    try {
      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved to profiles/{uid}.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not save profile.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickAvatarImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 900,
    );
    if (image == null || !mounted) {
      return;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final fileName =
        'wanderjoy_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedAvatar = await File(image.path).copy(
      '${documentsDir.path}/$fileName',
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _avatarUrlController.text = savedAvatar.path;
    });
  }

  void _hydrateForm(User user, DocumentSnapshot<Map<String, dynamic>>? profile) {
    if (_hasHydratedForm && _hydratedProfileId == user.uid) {
      return;
    }

    final data = profile?.data();
    final interests = data?['interests'];

    _avatarUrlController.text = _readString(
      data,
      'avatarUrl',
      fallback: user.photoURL ?? '',
    );
    _displayNameController.text = _readString(
      data,
      'displayName',
      fallback: user.displayName ?? '',
    );
    _ageController.text = _readNumber(data, 'age', fallback: 24);
    _interestsController.text = interests is Iterable
        ? interests.map((interest) => interest.toString()).join(', ')
        : '';
    _bioController.text = _readString(data, 'bio');
    _preferredIntensity = _readString(
      data,
      'preferredIntensity',
      fallback: 'Medium',
    );
    _safetyRatingController.text = _readNumber(
      data,
      'safetyRating',
      fallback: 5.0,
    );
    _hasHydratedForm = true;
    _hydratedProfileId = user.uid;
  }

  String _readString(
    Map<String, dynamic>? data,
    String key, {
    String fallback = '',
  }) {
    final value = data?[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return fallback;
  }

  String _readNumber(
    Map<String, dynamic>? data,
    String key, {
    num fallback = 0,
  }) {
    final value = data?[key];
    if (value is num) {
      return value.toString();
    }
    return fallback.toString();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? AuthService.instance.currentUser;
        final isPreviewMode = AuthService.instance.isPreviewMode;

        if (isPreviewMode) {
          return _ProfileBody(
            displayName: 'Preview Explorer',
            email: 'Preview mode active',
            avatarUrl: '',
            safetyRating: '5.0',
            form: _buildPreviewForm(context),
            onAvatarTap: null,
            onSignOut: _isSigningOut ? null : _handleSignOut,
            signOutLabel: _isSigningOut ? 'Signing Out...' : 'Exit Preview Mode',
            isSigningOut: _isSigningOut,
          );
        }

        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('profiles')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data;
            final data = profile?.data();

            if (profileSnapshot.hasData) {
              _hydrateForm(user, profile);
            }

            final displayName = _readString(
              data,
              'displayName',
              fallback: user.displayName?.trim().isNotEmpty ?? false
                  ? user.displayName!
                  : 'WanderJoy Explorer',
            );
            final savedAvatarUrl = _readString(
              data,
              'avatarUrl',
              fallback: user.photoURL ?? '',
            );
            final avatarUrl = _avatarUrlController.text.trim().isNotEmpty
                ? _avatarUrlController.text.trim()
                : savedAvatarUrl;
            final safetyRating = _readNumber(
              data,
              'safetyRating',
              fallback: 5.0,
            );
            final email = user.email?.trim().isNotEmpty ?? false
                ? user.email!
                : 'No email available';

            return _ProfileBody(
              displayName: displayName,
              email: email,
              avatarUrl: avatarUrl,
              safetyRating: safetyRating,
              form: _buildProfileForm(user, profile?.exists ?? false),
              onAvatarTap: _pickAvatarImage,
              onSignOut: _isSigningOut ? null : _handleSignOut,
              signOutLabel: _isSigningOut ? 'Signing Out...' : 'Log Out',
              isSigningOut: _isSigningOut,
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewForm(BuildContext context) {
    return DopamineCard(
      child: Text(
        'Sign in with Google to create and edit your Firestore profile.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildProfileForm(User user, bool profileExists) {
    return Form(
      key: _formKey,
      child: DopamineCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _DocumentIdPill(uid: user.uid),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _TextField(
              controller: _displayNameController,
              label: 'Display Name',
              icon: Icons.badge_outlined,
              validator: _requiredText,
            ),
            _TextField(
              controller: _ageController,
              label: 'Age',
              icon: Icons.cake_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _ageValidator,
            ),
            _TextField(
              controller: _interestsController,
              label: 'Interests',
              icon: Icons.favorite_outline,
              helperText: 'Separate interests with commas',
            ),
            _IntensitySelector(
              value: _preferredIntensity,
              onChanged: (value) {
                setState(() {
                  _preferredIntensity = value;
                });
              },
            ),
            _TextField(
              controller: _safetyRatingController,
              label: 'Safety Rating',
              icon: Icons.verified_user_outlined,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _ratingValidator,
            ),
            _TextField(
              controller: _bioController,
              label: 'Bio',
              icon: Icons.notes_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: _isSaving ? 'Saving...' : 'Save Profile',
              icon: Icons.save_outlined,
              onPressed: _isSaving
                  ? null
                  : () => _saveProfile(user, profileExists),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a display name.';
    }
    return null;
  }

  String? _ageValidator(String? value) {
    final age = int.tryParse(value?.trim() ?? '');
    if (age == null) {
      return 'Please enter your age.';
    }
    if (age < 13 || age > 120) {
      return 'Age must be between 13 and 120.';
    }
    return null;
  }

  String? _ratingValidator(String? value) {
    final rating = double.tryParse(value?.trim() ?? '');
    if (rating == null) {
      return 'Please enter a safety rating.';
    }
    if (rating < 0 || rating > 5) {
      return 'Safety rating must be between 0 and 5.';
    }
    return null;
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.safetyRating,
    required this.form,
    required this.onAvatarTap,
    required this.onSignOut,
    required this.signOutLabel,
    required this.isSigningOut,
  });

  final String displayName;
  final String email;
  final String avatarUrl;
  final String safetyRating;
  final Widget form;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSignOut;
  final String signOutLabel;
  final bool isSigningOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        140,
      ),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Column(
            children: [
              _ProfileAvatar(
                avatarUrl: avatarUrl,
                onTap: onAvatarTap,
              ),
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
              const SizedBox(height: 10),
              _SafetyBadge(value: safetyRating),
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
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        form,
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: isSigningOut
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: Text(signOutLabel),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.onTap,
  });

  final String avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trimmed = avatarUrl.trim();
    Widget avatar;
    if (trimmed.startsWith('http')) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.network(
          trimmed,
          width: 132,
          height: 132,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const _AvatarFallback(),
        ),
      );
    } else if (trimmed.isNotEmpty && File(trimmed).existsSync()) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.file(
          File(trimmed),
          width: 132,
          height: 132,
          fit: BoxFit.cover,
        ),
      );
    } else {
      avatar = const _AvatarFallback();
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (onTap != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
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

class _SafetyBadge extends StatelessWidget {
  const _SafetyBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 6),
          Text(
            'Safety Rating $value',
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.helperText,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final String? helperText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: AppColors.backgroundSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _IntensitySelector extends StatelessWidget {
  const _IntensitySelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = ['Relaxed', 'Medium', 'Active'];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferred Intensity',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (option) => ChoiceChip(
                    label: Text(option),
                    selected: value == option,
                    onSelected: (_) => onChanged(option),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DocumentIdPill extends StatelessWidget {
  const _DocumentIdPill({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final shortUid = uid.length > 8 ? '${uid.substring(0, 8)}...' : uid;

    return Tooltip(
      message: 'profiles/$uid',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.secondarySoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'uid $shortUid',
          style: const TextStyle(
            color: AppColors.secondary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
