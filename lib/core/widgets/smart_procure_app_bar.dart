import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SmartProcureAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;

  const SmartProcureAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,

      leading: showBack
          ? IconButton(
        tooltip: 'Back',
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 21,
          color: Color(0xFF12372A),
        ),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/farmer/home');
          }
        },
      )
          : null,

      titleSpacing: showBack ? 0 : 20,

      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF12372A),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),

      actions: actions,
    );
  }
}