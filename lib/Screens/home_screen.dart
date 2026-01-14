import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/scanner_screen.dart';
import 'package:ios_tiretest_ai/Screens/verhicle_form_preferences_screen.dart';
import 'package:ios_tiretest_ai/Widgets/gradient_text_widget.dart';





const kBg = Color(0xFFF6F7FA);

class InspectionHomePixelPerfect extends StatelessWidget {
  const InspectionHomePixelPerfect({super.key});

  

  void _toast(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _openTwoWheelerScanner(BuildContext context) async {
    final result = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) =>  ScannerFrontTireScreen(vehicleID: '',)),
    );
    if (result == null) return;

    //  Navigator.of(context, rootNavigator: true).push(
    //                   MaterialPageRoute(
    //                     builder: (_) => const ScannerFrontTireScreen(),
    //                   ),
    //                 );

    final authState = context.read<AuthBloc>().state;
    final box = GetStorage();
    final token = (box.read<String>('auth_token') ?? '').trim();

    if (token.isEmpty) {
      _toast(context, 'Please login again.');
      return;
    }

    context.read<AuthBloc>().add(
          UploadTwoWheelerRequested(
            userId: authState.profile!.userId.toString(),
            vehicleId: '993163bd-01a1-4c3b-9f18-4df2370ed954',
            token: token,
            frontPath: result.frontPath,
            backPath: result.backPath,
            vehicleType: 'bike',
            vin: result.vin,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    

    final size = MediaQuery.sizeOf(context);
    const baseW = 393.0;
    final s = size.width / baseW;


    final carH = (size.height * 0.30).clamp(210 * s, 360.0);   
    final bikeH = (size.height * 0.30).clamp(200 * s, 350.0);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 100 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 6 * s),
              _Header(s: s),
              SizedBox(height: 16 * s),
              _SearchBar(s: s),
              SizedBox(height: 25 * s),
              _CarCard(s: s, height: carH, width: size.width),
              SizedBox(height: 22 * s),
              InkWell(
                onTap: () => _openTwoWheelerScanner(context),
                child: _BikeCard(s: s, height: bikeH, width: size.width),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _Header extends StatelessWidget {
  const _Header({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (p, c) => p.profile != c.profile,
      builder: (context, state) {
        final profile = state.profile;

        final raw = (profile?.profileImage ?? '').toString().trim();
        final avatar = (raw.toLowerCase() == 'null') ? '' : raw;

        bool isHttp(String v) {
          final u = Uri.tryParse(v);
          return u != null &&
              u.hasScheme &&
              (u.scheme == 'http' || u.scheme == 'https') &&
              u.host.isNotEmpty;
        }

        String normalizeFilePath(String v) {
          // file:///var/... => /var/...
          if (v.startsWith('file://')) return Uri.parse(v).toFilePath();
          return v;
        }

        Widget avatarWidget() {
          // ✅ 1) local file path
          if (avatar.isNotEmpty && !isHttp(avatar)) {
            final path = normalizeFilePath(avatar);
            final f = File(path);

            if (f.existsSync()) {
              return Image.file(
                f,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    Image.asset('assets/avatar.png', fit: BoxFit.cover),
              );
            }

            // If file missing, show fallback
            return Image.asset('assets/avatar.png', fit: BoxFit.cover);
          }

          // ✅ 2) network
          if (avatar.isNotEmpty && isHttp(avatar)) {
            return Image.network(
              avatar,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  Image.asset('assets/avatar.png', fit: BoxFit.cover),
            );
          }

          // ✅ 3) fallback
          return Image.asset('assets/avatar.png', fit: BoxFit.cover);
        }

        final name = (profile != null)
            ? '${profile.firstName} ${profile.lastName}'.trim()
            : 'User';

        return Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 14 * s,
                    color: const Color(0xFF6A6F7B),
                    height: 1.2,
                  ),
                  children: [
                    TextSpan(
                      text: 'Good morning,\n',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 21 * s,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GradientText(
                        name,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                        ),
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 28 * s,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12 * s),

            // ✅ Perfect circle
            Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8 * s,
                    offset: Offset(0, 4 * s),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias, // ✅ important
              child: avatarWidget(),
            ),
          ],
        );
      },
    );
  }
}


/*

class _Header extends StatelessWidget {
  const _Header({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    final profile = context.read<AuthBloc>().state.profile;

    final avatar = (profile!.profileImage ?? '').toString();

    Widget avatarWidget() {
  // local file
  if (avatar.isNotEmpty && !avatar.startsWith('http')) {
    final f = File(avatar);
    if (f.existsSync()) {
      return Image.file(f, fit: BoxFit.cover);
    }
  }

  // network url
  if (avatar.isNotEmpty && avatar.startsWith('http')) {
    return Image.network(
      avatar,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Image.asset('assets/avatar.png', fit: BoxFit.cover),
    );
  }

  // fallback
  return Image.asset('assets/avatar.png', fit: BoxFit.cover);
}


        // Widget avatarWidget() {
        //   // if local file path exists
        //   if (avatar.isNotEmpty && !avatar.startsWith('http')) {
        //     final f = File(avatar);
        //     if (f.existsSync()) {
        //       return Image.file(f, fit: BoxFit.cover);
        //     }
        //   }

        //   // if network url
        //   if (avatar.isNotEmpty && avatar.startsWith('http')) {
        //     return Image.network(avatar, fit: BoxFit.cover);
        //   }

        //   return Image.asset('assets/avatar.png', fit: BoxFit.cover);
        // }

          
    final name = (profile != null)
        ? '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim()
        : 'User';

        final profilePicture = (profile != null)
        ? '${profile.profileImage ?? ''}'
        : '';

    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                color: const Color(0xFF6A6F7B),
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: 'Good morning,\n',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 21 * s,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: 0.1 * s,
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GradientText(
                    name,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 28 * s,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      letterSpacing: 0.1 * s,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12 * s),
        // avatarWidget(),
        Container(
          height: 80,
          width: 80,
         // padding: EdgeInsets.all(2 * s),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8 * s,
                offset: Offset(0, 4 * s),
              ),
            ],
          ),
          child:  ClipOval(child: avatarWidget()),
        ),
      ],
    );
  }
}
*/
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50 * s,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
      ),
      padding: EdgeInsets.only(right: 16 * s),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Container(
            width: 38 * s,
            height: 38 * s,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, size: 20, color: Colors.black),
          ),
          SizedBox(width: 10 * s),
          Expanded(
            child: TextField(
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: Colors.black54,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search the latest inspection',
                hintStyle: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({
    required this.s,
    required this.height,
    required this.width,
  });

  final double s;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final radius = 14 * s;

    return Container(
      height: height,
      width: width - (32 * s),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/carcardbg.png'),
          fit: BoxFit.fitHeight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B63FF).withOpacity(.15),
            blurRadius: 20 * s,
            offset: Offset(0, 10 * s),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
           // left: -10,
            right: 0,
            top: -6 * s,
            child: SizedBox(
              width: height * 0.80,
              height: height * 0.99,
              child: Image.asset(
                'assets/car_tyres_1_2000x3000.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Car Wheel\nInspection',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: Colors.white,
                    fontSize: 29 * s,
                    fontWeight: FontWeight.bold,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 9 * s),
                Text(
                  'Scan your car wheels\nto detect wear & damage',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 16.5 * s,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const VehicleFormPreferencesScreen()
                      ),
                    );
                  },
                  child: _ChipButtonWhite(
                    s: s,
                    icon: 'assets/scan_icon.png',
                    label: 'Scan Car Tries',
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

/* ------------------------ Bike Card ------------------------ */
class _BikeCard extends StatelessWidget {
  const _BikeCard({
    required this.s,
    required this.height,
    required this.width,
    this.onTap,
  });

  final double s;
  final double height;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width - (32 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18 * s,
            offset: Offset(0, 10 * s),
          ),
        ],
        image: const DecorationImage(
          image: AssetImage('assets/bike_wheel.png'),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(.96),
                  Colors.white.withOpacity(.15),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientText(
                  'Bike Wheel\nInspection',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 29 * s,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 6 * s),
                Text(
                  'Analyze your motorcycle\ntires and get a report',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: const Color(0xFF444B59),
                    fontSize: 16.5 * s,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onTap,
                  child: _ChipButtonGradient(
                    s: s,
                    label: 'Scan Bike Tries',
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

class _ChipButtonWhite extends StatelessWidget {
  const _ChipButtonWhite({
    required this.s,
    required this.icon,
    required this.label,
  });
  final double s;
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40 * s,
      padding: EdgeInsets.symmetric(horizontal: 12 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12 * s,
            offset: Offset(0, 6 * s),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            icon,
            height: 22 * s,
            width: 22 * s,
            color: Colors.black,
          ),
          SizedBox(width: 8 * s),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: const Color(0xFF1F2937),
              fontSize: 16 * s,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipButtonGradient extends StatelessWidget {
  const _ChipButtonGradient({required this.s, required this.label});
  final double s;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40 * s,
      padding: EdgeInsets.symmetric(horizontal: 12 * s),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
        ),
        borderRadius: BorderRadius.circular(5 * s),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F53FD).withOpacity(0.25),
            blurRadius: 12 * s,
            offset: Offset(0, 6 * s),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/scan_icon.png',
            height: 22 * s,
            width: 22 * s,
            color: Colors.white,
          ),
          SizedBox(width: 8 * s),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Colors.white,
              fontSize: 16 * s,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
