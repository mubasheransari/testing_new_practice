// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Screens/location_google_maos.dart';
import 'package:ios_tiretest_ai/Screens/report_history_screen.dart';
import 'package:ios_tiretest_ai/Screens/scanner_screen.dart';
import 'package:ios_tiretest_ai/Widgets/gradient_text_widget.dart';

const kBg = Color(0xFFF6F7FA);
const kTxtDim = Color(0xFF6A6F7B);
const kTxtDark = Color(0xFF1F2937);
const kSearchBg = Color(0xFFF0F2F5);
const kIconMuted = Color(0xFF9CA3AF);
const kBikeText = Color(0xFF444B59);

const kGradBluePurple = LinearGradient(
  colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

const kCardCarGrad = LinearGradient(
  colors: [Color(0xFF1CC8FF), Color(0xFF6B63FF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Pixel-perfect screen; base width 393 for scaling.
/// Replace avatar/wheel images with your assets for a 1:1 look.
class InspectionHomePixelPerfect extends StatelessWidget {
  const InspectionHomePixelPerfect({super.key});

  static const _bg = Color(0xFFF6F7FA);
  static const _txtDim = Color(0xFF6A6F7B);
  static const _txtDark = Color(0xFF1F2937);
  static const _searchBg = Color(0xFFF0F2F5);
  static const _iconMuted = Color(0xFF9CA3AF);
  static const _bikeText = Color(0xFF444B59);

  static const _gradBluePurple = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  void _toast(BuildContext ctx, String msg) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));

Future<void> _openTwoWheelerScanner(BuildContext context) async {
  // Navigate to your camera/reticle screen to capture FRONT + BACK
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ScannerFrontTireScreen()),
  );

  // User backed out
  if (result == null) return;

  // Grab anything you need from auth state (token, userId, selected vehicleId)
  final authState = context.read<AuthBloc>().state;
   final box   = GetStorage();  
      final token = (box.read<String>('auth_token') ?? '').trim();//final token     = authState.loginResponse?.token ?? '';      // adjust field names
  // final userId    = '';
  // final vehicleId = 'YOUR_SELECTED_BIKE_ID';                   // supply from your UI/selection

  if (token.isEmpty ) {
    _toast(context, 'Please login again.');
    return;
  }

  // Fire the upload event (this triggers the “generating” flow)
  context.read<AuthBloc>().add(UploadTwoWheelerRequested(
        userId:    context.read<AuthBloc>().state.profile!.userId.toString(),
        vehicleId: '993163bd-01a1-4c3b-9f18-4df2370ed954',
        token:     token,
        frontPath: result.frontPath,
        backPath:  result.backPath,
        vehicleType: 'bike',
        vin: result.vin, // optional
  ));

  // Optionally show a “Generating Report” screen while Bloc uploads/parses
  // Navigator.push(context,
  //   MaterialPageRoute(builder: (_) => const GeneratingReportScreen()),
  // );
}


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const baseW = 393.0; // iPhone 14/15 base
    final s = size.width / baseW;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 100 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    SizedBox(height: 6 * s),
                  _Header(s: s),
                  SizedBox(height: 16 * s),
                  _SearchBar(s: s),
                  SizedBox(height: 25 * s),
                  _CarCard(s: s),
                  SizedBox(height: 30 * s),
                  InkWell(
                    onTap: (){
                     _openTwoWheelerScanner(context);
                    },
                    child: _BikeCard(s: s)),
                ],
              ),
            ),

        
          ],
        ),
      ),
    );
  }
}

/* ------------------------ Header ------------------------ */
class _Header extends StatelessWidget {
  const _Header({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'ClashGrotesk',//Testing@123
                fontSize: 14 * s,
                color: Color(0xFF6A6F7B),
                height: 1.2,
              ),
              children: [
                 TextSpan(text: 'Good morning,\n',   style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 21 * s,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: 0.1 * s,
                    ),),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GradientText(
                  "${context.read<AuthBloc>().state.profile!.firstName.toString() + context.read<AuthBloc>().state.profile!.lastName.toString()}", // 'William David',
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
        SizedBox(width: 10 * s),
        Container(
          padding: EdgeInsets.all(2 * s),
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
          child: CircleAvatar(
            radius: 30 * s,
            backgroundImage: const AssetImage('assets/avatar.png'),
          ),
        ),
      ],
    );
  }
}

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
            child: const Icon(
              Icons.search,
              size: 20,
              color: Colors.black,
            ),
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


// class _SearchBar extends StatelessWidget {
//   const _SearchBar({required this.s});
//   final double s;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 50 * s,
//       decoration: BoxDecoration(
//         color: Colors.grey[300],
//         borderRadius: BorderRadius.circular(999),
//       ),
//       padding: EdgeInsets.only(right: 16 * s),
//       child: Row(
//         children: [
//           const SizedBox(width: 6),
//           Container(
//             width: 38 * s,
//             height: 38 * s,
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               Icons.search,
//               size: 20 * s,
//               color: Colors.black,
//             ),
//           ),
//           SizedBox(width: 12 * s),
//           Expanded(
//             child: Text(
//               'Search the latest inspection',
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14 * s,
//                 color:  Colors.black87,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



class _CarCard extends StatelessWidget {
  const _CarCard({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    final radius = 9 * s;

    return Container(
      height: 210 * s,
      width: MediaQuery.of(context).size.width * 0.90,
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/carcardbg.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B63FF),
            // blurRadius: 20 * s,
            // offset: Offset(0, 10 * s),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 👇 wrapped in ClipRRect + pulled a bit inside to avoid right-side blur
          Positioned(
            right: 0, // keep inside the rounded card
            top: -6 * s,
            child: ClipRRect(
              // borderRadius: BorderRadius.only(
              //   topRight: Radius.circular(radius),
              //   bottomRight: Radius.circular(radius),
              // ),
              child: SizedBox(
                width: 180 * s,
                height: 255 * s,
                child: Image.asset(
                  'assets/car_tyres.png',
                  fit: BoxFit.contain,
                ),
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
                SizedBox(height: 22),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScannerFrontTireScreen(),
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


class _BikeCard extends StatelessWidget {
  const _BikeCard({required this.s, this.onTap});
  final double s;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 205 * s,
      width: MediaQuery.of(context).size.width * 0.90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9 * s),
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
          // light overlay so text stays readable
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(.95),
                  Colors.white.withOpacity(.2),
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





/* ------------------------ Chip Buttons ------------------------ */
class _ChipButtonWhite extends StatelessWidget {
  const _ChipButtonWhite({required this.s, required this.icon, required this.label});
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
        Image.asset(icon,height: 22 * s,width: 22 * s,color: Colors.black,), // Icon(icon, color: Color(0xFF1F2937), size: 18 * s),
          SizedBox(width: 8 * s),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Color(0xFF1F2937),
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
                  Image.asset('assets/scan_icon.png',height: 22 * s,width: 22 * s,color: Colors.white,),
        //  Icon(icon, color: Colors.white, size: 18 * s),
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




