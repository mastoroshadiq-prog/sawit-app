// lib/screens/widgets/w_login.dart
import 'dart:async';

import 'package:flutter/material.dart';
import '../../mvc_services/api_auth.dart';
import '../../plantdb/db_helper.dart';
import '../../mvc_models/petugas.dart';
import '../../mvc_dao/dao_petugas.dart';
import 'w_general.dart';

Container contLatarBelakang() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFF004D40), // Hijau tua pekat
          Color(0xFF388E3C), // Hijau sedang
          Color(0xFF8BC34A), // Hijau muda segar
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  );
}

DecoratedBox boxLatarBelakang() {
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.4), // Gelap di atas
          Colors.black.withValues(alpha: 0.2), // Sedikit gelap di tengah
          const Color(
            0xFF004D40,
          ).withValues(alpha: 0.6), // Warna hijau tua transparan
        ],
      ),
    ),
  );
}

BoxDecoration loginBoxDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.9), // Sedikit transparan
    borderRadius: BorderRadius.circular(20), // Sudut lebih membulat
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

Widget loginContent(
  TextEditingController usernameController,
  TextEditingController passwordController,
  Animation<double> objAnimation,
  BuildContext context,
  String assignmentRoute,
  String strRoute,
) {
  return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: FadeTransition(
        // Animasi fade-in untuk seluruh konten
        opacity: objAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            cardLoginContainer(
              context,
              usernameController,
              passwordController,
              assignmentRoute,
              strRoute,
            ),
          ],
        ),
      ),
    ),
  );
}

Container cardLoginContainer(
  BuildContext context,
  TextEditingController usernameController,
  TextEditingController passwordController,
  String assignmentRoute,
  String strRoute,
) {
  return Container(
    padding: const EdgeInsets.all(30.0),
    decoration: loginBoxDecoration(),
    child: Column(
      mainAxisSize: MainAxisSize.min, // Agar card tidak memakan seluruh tinggi
      children: listChildren(
        context,
        usernameController,
        passwordController,
        assignmentRoute,
        strRoute,
      ),
    ),
  );
}

List<Widget> listChildren(
  BuildContext context,
  TextEditingController usernameController,
  TextEditingController passwordController,
  String assignmentRoute,
  String strRoute,
) {
  return [
    Image.asset(
      'assets/icons/normal.png',
      width: 80,
      height: 80,
      fit: BoxFit.contain,
    ),
    const SizedBox(height: 25),
    ResText('Selamat Datang', 30, FontStyle.normal, true, Color(0xFF1B5E20)),
    const SizedBox(height: 25),
    // Field Input Username
    _buildTextField(
      textController: usernameController,
      labelText: 'Akun Pengguna',
      icon: Icons.person_outline,
    ),
    const SizedBox(height: 20),
    // Field Input Password
    _buildTextField(
      textController: passwordController,
      labelText: 'Kata Sandi',
      icon: Icons.lock_outline,
      obscureText: false,
      isPasswordField: true,
    ),
    const SizedBox(height: 30),
    tombolLogin(
      context,
      assignmentRoute,
      usernameController,
      passwordController,
    ),
    const SizedBox(height: 15),
    lupaSandi(),
    //const SizedBox(height: 5),
    //testSQLite(context, sqliteRoute),
  ];
}

ElevatedButton tombolLogin(
  BuildContext context,
  String routeName,
  TextEditingController usernameController,
  TextEditingController passwordController,
) {
  //final db = await DBHelper().instance.database;
  return ElevatedButton(
    onPressed: () async {
      final username = usernameController.text.trim();
      final password = passwordController.text.trim();

      // print('{$username}, {$password}');

      if (username.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username dan Password wajib diisi")),
        );
        return;
      }

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await DBHelper()
            .cleanDatabaseAfterLogin()
            .timeout(const Duration(seconds: 12));

        // 🌐 1. Panggil API untuk login
        final result = await ApiAuth.login(username, password);
        if (!context.mounted) return;

        if (result['success']) {
          final data = result['data'];

          // 2. Buat objek Petugas
          final petugas = Petugas(
            akun: username,
            nama: data['nama'],
            kontak: data['id_pihak'],
            peran: data['tipe'],
            lastSync: '',
            blok: data['blok'],
            divisi: data['divisi'],
          );

          // 3. Simpan ke SQLite via DAO
          final hasil = await PetugasDao().insertPetugas(petugas);
          if (!context.mounted) return;

          // 4. Navigate ke halaman Sync
          if (hasil > 0) {
            Navigator.pushReplacementNamed(
              context,
              routeName,
              arguments: {'username': username, 'blok': petugas.blok},
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal menyimpan data user lokal")),
          );
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'])));
      } on TimeoutException {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proses login terlalu lama, periksa jaringan lalu coba lagi'),
          ),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kendala saat login, silakan coba ulang'),
          ),
        );
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF388E3C), // Hijau Sedang
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 55), // Tombol lebih besar
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), // Sudut tombol membulat
      ),
      elevation: 8, // Sedikit bayangan untuk tombol
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text(
          'MASUK',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(width: 8),
        Icon(Icons.chevron_right, size: 35),
      ],
    ),
  );
}

TextButton lupaSandi() {
  return TextButton(
    onPressed: () {
      // TODO: Implementasi Forgot Password
    },
    child: const Text(
      //'Beta Version 1.0.0',
      'Beta Version 1.0.1',
      style: TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.w600),
    ),
  );
}

TextButton testSQLite(BuildContext context, String routeName) {
  return TextButton(
    onPressed: () {
      // TODO: Implementasi Forgot Password
      Navigator.pushNamed(context, routeName);
    },
    child: const Text(
      'Reset Data',
      style: TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.w600),
    ),
  );
}

InputDecoration kolomTeks(String labelText, IconData icon) {
  return InputDecoration(
    labelText: labelText,
    prefixIcon: resIconConfig(icon, null, Color(0xFF388E3C)),
    border: resOutlineInputBorderConfig(12.0, resNoneBorderSide()),
    filled: true,
    fillColor: Colors.grey[100], // Warna latar belakang input field
    focusedBorder: resOutlineInputBorderConfig(
      12.0,
      resBorderSideConfig(Color(0xFF388E3C), 2),
    ),
    enabledBorder: resOutlineInputBorderConfig(
      12.0,
      resBorderSideConfig(Colors.grey[300]!, 1),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
    labelStyle: const TextStyle(color: Colors.black87),
    hintStyle: TextStyle(color: Colors.grey[600]),
  );
}

Widget _buildTextField({
  required TextEditingController textController,
  required String labelText,
  required IconData icon,
  bool obscureText = false,
  bool isPasswordField = false,
}) {
  if (!isPasswordField) {
    return resTextFieldConfig(
      textController,
      icon,
      obscureText,
      kolomTeks(labelText, icon),
      resTextStyle(null, null, false, Colors.black87),
    );
  }

  bool hidden = true;
  return StatefulBuilder(
    builder: (context, setState) {
      return TextField(
        controller: textController,
        obscureText: hidden,
        style: resTextStyle(null, null, false, Colors.black87),
        decoration: kolomTeks(labelText, icon).copyWith(
          suffixIcon: IconButton(
            onPressed: () => setState(() => hidden = !hidden),
            icon: Icon(
              hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF388E3C),
            ),
          ),
        ),
      );
    },
  );
}
