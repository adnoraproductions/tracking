import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/adnora_logo.dart';
import '../../../shared/widgets/glass_text_field.dart';
import '../../../shared/widgets/liquid_button.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

/// Login role toggle
final selectedLoginRoleProvider = StateProvider<int>((ref) => 0); // 0 = Admin, 1 = Employee

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', email);
    } else {
      await prefs.remove('saved_email');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    await _saveEmail(email);
    await ref.read(authNotifierProvider.notifier).signIn(email: email, password: password);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;
    final selectedRole = ref.watch(selectedLoginRoleProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    ref.listen<AuthState>(authNotifierProvider, (prev, next) async {
      if (next is AuthAuthenticated) {
        final repo = ref.read(authRepositoryProvider);
        final profile = await repo.fetchProfile(next.userId);
        if (!context.mounted) return;
        if (profile == null || !profile.onboardingComplete) {
          context.go(AppRoutes.onboarding);
        } else {
          context.go(AppRoutes.dashboard);
        }
      }
      if (next is AuthError && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: context.colors.error.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // ─── Animated mesh gradient background ─────────────
          _AnimatedMeshBackground(controller: _bgController, role: selectedRole),

          // ─── Content ───────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: screenHeight * 0.05),

                      // ─── Logo ──────────────────────────────
                      const AdnoraLogo(
                        size: AdnoraLogoSize.large,
                        showTagline: false,
                        showText: false,
                      )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .scale(
                            begin: const Offset(0.85, 0.85),
                            end: const Offset(1, 1),
                            duration: 700.ms,
                            curve: Curves.easeOutBack,
                          ),

                      SizedBox(height: screenHeight * 0.04),
                      // ─── Login Role Toggle ───────────────────────
                      _LoginRoleToggle(
                        selectedRole: selectedRole,
                        onChanged: (val) {
                          ref.read(selectedLoginRoleProvider.notifier).state = val;
                          HapticFeedback.selectionClick();
                        },
                      ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),

                      const SizedBox(height: AppSpacing.xxl),

                      // ─── Glass Login Card ──────────────────
                      _GlassLoginCard(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        isLoading: isLoading,
                        onLogin: _handleSignIn,
                        isAdmin: selectedRole == 0,
                        rememberMe: _rememberMe,
                        onRememberMeChanged: (val) {
                          setState(() {
                            _rememberMe = val ?? false;
                          });
                        },
                      )
                          .animate(delay: 400.ms)
                          .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                          .slideY(
                            begin: 0.06,
                            end: 0,
                            duration: 600.ms,
                            curve: Curves.easeOutCubic,
                          ),

                      SizedBox(height: screenHeight * 0.05),

                      // ─── Footer ────────────────────────────
                      Text(
                        '© ${DateTime.now().year} Adnora Productions',
                        style: AppTypography.caption.copyWith(
                          color: context.colors.textDisabled,
                        ),
                      ).animate(delay: 600.ms).fadeIn(duration: 400.ms),

                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Glass Login Card ─────────────────────────────────────────
class _GlassLoginCard extends StatelessWidget {
  const _GlassLoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
    required this.isAdmin,
    required this.rememberMe,
    required this.onRememberMeChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLogin;
  final bool isAdmin;
  final bool rememberMe;
  final ValueChanged<bool?> onRememberMeChanged;

  @override
  Widget build(BuildContext context) {
    final accentColor = isAdmin ? context.colors.amber : context.colors.cyan;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: context.colors.glassFill,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
              border: Border.all(color: context.colors.glassBorder, width: 0.5),
            ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email field
                GlassTextField(
                  controller: emailController,
                  label: isAdmin ? 'Admin Email' : 'Employee Email',
                  hint: isAdmin ? 'admin@adnora.com' : 'you@adnora.com',
                  prefixIcon: isAdmin
                      ? Icons.shield_outlined
                      : Icons.badge_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  enabled: !isLoading,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '${isAdmin ? "Admin email" : "Email"} is required';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                // Password field
                GlassTextField(
                  controller: passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  enabled: !isLoading,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                // Remember Me
                Row(
                  children: [
                    Theme(
                      data: ThemeData(
                        unselectedWidgetColor: context.colors.textDisabled,
                        checkboxTheme: CheckboxThemeData(
                          fillColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return accentColor;
                            }
                            return Colors.transparent;
                          }),
                          checkColor: WidgetStateProperty.all(Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      child: Checkbox(
                        value: rememberMe,
                        onChanged: onRememberMeChanged,
                      ),
                    ),
                    Text(
                      'Remember Me',
                      style: AppTypography.bodySmall.copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Sign In Button
                LiquidButton(
                  label: 'Sign In',
                  expanded: true,
                  icon: isAdmin
                      ? Icons.admin_panel_settings_rounded
                      : Icons.login_rounded,
                  isLoading: isLoading,
                  onPressed: onLogin,
                ),


              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}



// ─── Animated Mesh Background ─────────────────────────────────
class _AnimatedMeshBackground extends StatelessWidget {
  const _AnimatedMeshBackground({
    required this.controller,
    required this.role,
  });

  final AnimationController controller;
  final int role;

  @override
  Widget build(BuildContext context) {
    final accentColor = role == 0 ? context.colors.amber : context.colors.cyan;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value * 2 * math.pi;
        return Stack(
          children: [
            // Primary orb
            Positioned(
              top: -80 + math.sin(t * 0.3) * 30,
              right: -50 + math.cos(t * 0.2) * 40,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Secondary orb
            Positioned(
              bottom: -100 + math.cos(t * 0.25) * 25,
              left: -70 + math.sin(t * 0.15) * 35,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      context.colors.brand.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Accent orb
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4 + math.sin(t * 0.4) * 20,
              right: -100 + math.cos(t * 0.35) * 30,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      context.colors.pink.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Login Role Toggle ──────────────────────────────────────────
class _LoginRoleToggle extends StatelessWidget {
  const _LoginRoleToggle({required this.selectedRole, required this.onChanged});
  
  final int selectedRole;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.glassBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(
            title: 'Admin',
            icon: Icons.shield_rounded,
            isSelected: selectedRole == 0,
            activeColor: colors.brand,
            onTap: () => onChanged(0),
          ),
          _ToggleOption(
            title: 'Employee',
            icon: Icons.badge_rounded,
            isSelected: selectedRole == 1,
            activeColor: colors.cyan,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : colors.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTypography.labelLarge.copyWith(
                color: isSelected ? activeColor : colors.textTertiary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
