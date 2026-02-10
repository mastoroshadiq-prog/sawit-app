// screens/koreksi_temuan_screen.dart
import 'package:flutter/material.dart';
import '../screens/widgets/w_general.dart';

class OptionActScreen extends StatefulWidget {
  const OptionActScreen({super.key});

  @override
  State<OptionActScreen> createState() => _OptionActScreenState();
}

class _OptionActScreenState extends State<OptionActScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: cfgAppBar('Aksi Pohon', Colors.lightGreen.shade900),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _resMenu(context),
        ],
      ),
    );
  }

  Card _resMenu(BuildContext context) {
    return resCardConfigStyle(
      cfgCenterColumn(
        children: [
          const SizedBox(height: 20),
          singleActionItem(context),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Koreksi dan Temuan (Ganoderma) kini ada dalam satu popup untuk input yang lebih cepat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green.shade800, fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
      20.0,
      20.0,
      const Color(0xFFE8F5E9),
    );
  }

  Widget singleActionItem(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _buildMenuItem(
          context,
          icon: Icons.forest,
          label: 'KOREKSI & TEMUAN',
          iconColor: Colors.white,
          circleColor: Colors.teal.shade700,
          onTap: cfgNavigator(
            context: context,
            action: 'push',
            routeName: '/reposisi',
          ),
        ),
      ],
    );
  }

  // Helper Widget (Disamakan dengan Menu Utama agar seragam)
  Widget _buildMenuItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        required Color iconColor,
        required Color circleColor,
      }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15.0),
        child: Container(
          width: 180,
          height: 140,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
