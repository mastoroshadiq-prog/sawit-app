// lib/screens/widgets/w_login.dart
import 'dart:async';

import 'package:flutter/material.dart';
import '../../mvc_services/api_auth.dart';
import '../../plantdb/db_helper.dart';
import '../../mvc_dao/dao_assignment.dart';
import '../../mvc_dao/dao_pohon.dart';
import '../../mvc_dao/dao_spr.dart';
import '../../mvc_models/petugas.dart';
import '../../mvc_dao/dao_petugas.dart';
import '../../mvc_libs/active_block_store.dart';
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

Widget tombolLogin(
  BuildContext context,
  String routeName,
  TextEditingController usernameController,
  TextEditingController passwordController,
) {
  Future<bool> isLocalMasterReadyForBlok(String blok) async {
    final block = blok.trim();
    if (block.isEmpty) return false;

    final assignmentCount = (await AssignmentDao().getAllAssignment()).length;
    final pohonCount = (await PohonDao().getAllPohonByBlok(block)).length;
    final sprCount = (await SPRDao().getByBlok(block)).length;

    return assignmentCount > 0 && pohonCount > 0 && sprCount > 0;
  }

  var isSubmitting = false;
  return StatefulBuilder(
    builder: (context, setButtonState) {

      return ElevatedButton(
        onPressed: isSubmitting
            ? null
            : () async {
                setButtonState(() => isSubmitting = true);
                final username = usernameController.text.trim();
                final password = passwordController.text.trim();

                if (username.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Username dan Password wajib diisi")),
                  );
                  setButtonState(() => isSubmitting = false);
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Memproses login...'),
                      duration: Duration(seconds: 30),
                    ),
                  );

                try {
                  final result = await Future.any<Map<String, dynamic>>([
                    ApiAuth.login(username, password),
                    Future<Map<String, dynamic>>.delayed(
                      const Duration(seconds: 20),
                      () => {
                        'success': false,
                        'message': 'Login timeout, silakan coba lagi',
                      },
                    ),
                  ]);
                  if (!context.mounted) return;

                  if (result['success']) {
                    final data = result['data'];

                    String safeStr(dynamic v, {String fallback = ''}) {
                      if (v == null) return fallback;
                      final s = v.toString().trim();
                      return s.isEmpty ? fallback : s;
                    }

                    final petugas = Petugas(
                      akun: safeStr(data['akun'], fallback: username),
                      nama: safeStr(data['nama'], fallback: username),
                      kontak: safeStr(data['id_pihak'], fallback: '-'),
                      peran: safeStr(data['tipe'], fallback: 'MANDOR'),
                      lastSync: '',
                      blok: safeStr(data['blok'], fallback: '-'),
                      divisi: safeStr(data['divisi'], fallback: '-'),
                    );

                    final existing = await PetugasDao().getPetugas();
                    final existingAkun = (existing?.akun ?? '').trim().toLowerCase();
                    final incomingAkun = petugas.akun.trim().toLowerCase();
                    final isUserSwitch =
                        existingAkun.isNotEmpty && existingAkun != incomingAkun;

                    if (isUserSwitch) {
                      await DBHelper()
                          .cleanDatabaseForUserSwitch()
                          .timeout(const Duration(seconds: 15));
                    }

                    final hasil = await PetugasDao().insertPetugas(petugas);
                    if (!context.mounted) return;

                    if (hasil > 0) {
                      final selectedBlok = petugas.blok.trim();
                      await ActiveBlockStore.set(selectedBlok);

                      final isLocalReady =
                          await isLocalMasterReadyForBlok(selectedBlok);

                      messenger.hideCurrentSnackBar();
                      if (!context.mounted) return;

                      if (isLocalReady) {
                        Navigator.pushReplacementNamed(context, '/menu');
                      } else {
                        Navigator.pushReplacementNamed(
                          context,
                          routeName,
                          arguments: {
                            'username': username,
                            'blok': petugas.blok,
                            'selectedBlok': petugas.blok,
                          },
                        );
                      }
                      return;
                    }

                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Gagal menyimpan data user lokal")),
                    );
                  } else {
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(SnackBar(content: Text(result['message'])));
                  }
                } on TimeoutException {
                  if (!context.mounted) return;
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Proses login terlalu lama, periksa jaringan lalu coba lagi'),
                    ),
                  );
                } catch (_) {
                  if (!context.mounted) return;
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Terjadi kendala saat login, silakan coba ulang'),
                    ),
                  );
                } finally {
                  if (context.mounted) {
                    setButtonState(() => isSubmitting = false);
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF388E3C),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 8,
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
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
    },
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
