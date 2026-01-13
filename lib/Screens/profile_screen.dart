import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Data/token_store.dart';
import 'package:ios_tiretest_ai/Screens/auth_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ✅ Add your imports
// import 'auth_screen.dart';
// import 'token_store.dart';
import '../Bloc/auth_bloc.dart';
import '../Bloc/auth_event.dart';
import '../Bloc/auth_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _bg = Color(0xFFF6F7FB);
  static const _title = Color(0xFF111111);
  static const _sub = Color(0xFF7D8790);
  static const _divider = Color(0xFFE9ECF2);

  static const _chipGrad = LinearGradient(
    colors: [Color(0xFF73D1FF), Color(0xFF6A7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size.width / 390.0;

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) => p.updateProfileStatus != c.updateProfileStatus,
      listener: (context, state) {
        if (state.updateProfileStatus == UpdateProfileStatus.success) {
          final msg = state.updateProfileResponse?.message ??
              "User details updated successfully";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
        if (state.updateProfileStatus == UpdateProfileStatus.failure) {
          final msg = state.updateProfileError ?? "Update failed";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      },
      builder: (context, state) {
        final profile = state.profile;

        final fullName = (profile == null)
            ? '--'
            : '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim();

        final email = profile?.email ?? '--';
        final phone = profile?.phone ?? '--';
        final avatarUrl = (profile?.profileImage ?? '').toString();

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 24 * s),
              children: [
                SizedBox(
                  height: 44 * s,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'Profile',
                        style: TextStyle(
                          letterSpacing: 1.0,
                          fontFamily: 'ClashGrotesk',
                          fontSize: 24 * s,
                          fontWeight: FontWeight.w600,
                          color: _title,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14 * s),

                // ===== Top: Avatar + Name + Edit Profile
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 96 * s,
                      height: 96 * s,
                      child: Stack(
                        children: [
                          Container(
                            width: 96 * s,
                            height: 96 * s,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEDEFF3), Colors.white],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.06),
                                  blurRadius: 16 * s,
                                  offset: Offset(0, 8 * s),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(3 * s),
                              child: ClipOval(
                                child: (avatarUrl.isNotEmpty &&
                                        avatarUrl.startsWith('http'))
                                    ? Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.asset(
                                        'assets/avatar.png',
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4 * s,
                            bottom: 4 * s,
                            child: Container(
                              width: 24 * s,
                              height: 24 * s,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: _divider),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.08),
                                    blurRadius: 8 * s,
                                    offset: Offset(0, 3 * s),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.photo_camera_outlined,
                                  size: 14 * s, color: _title),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 14 * s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isEmpty ? '--' : fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 20 * s,
                              fontWeight: FontWeight.w700,
                              color: _title,
                            ),
                          ),
                          SizedBox(height: 4 * s),
                          Text(
                            email,
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 14 * s,
                              fontWeight: FontWeight.w600,
                              color: _sub,
                            ),
                          ),
                          SizedBox(height: 4 * s),
                          Text(
                            phone,
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 14 * s,
                              fontWeight: FontWeight.w600,
                              color: _sub,
                            ),
                          ),
                          SizedBox(height: 10 * s),

                          // ✅ Edit Profile button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12 * s),
                              onTap: () {
                                _openEditProfileSheet(
                                  context,
                                  s: s,
                                  firstName: profile?.firstName ?? '',
                                  lastName: profile?.lastName ?? '',
                                  phone: profile?.phone ?? '',
                                  profileImage: profile?.profileImage ?? '',
                                );
                              },
                              child: Container(
                                height: 40 * s,
                                padding:
                                    EdgeInsets.symmetric(horizontal: 16 * s),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12 * s),
                                  gradient: _chipGrad,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6A7CFF)
                                          .withOpacity(.20),
                                      blurRadius: 12 * s,
                                      offset: Offset(0, 6 * s),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (state.updateProfileStatus ==
                                        UpdateProfileStatus.loading) ...[
                                      SizedBox(
                                        width: 16 * s,
                                        height: 16 * s,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 10 * s),
                                    ],
                                    Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontFamily: 'ClashGrotesk',
                                        fontSize: 14.5 * s,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 18 * s),
                _dividerLine(s),

                _menuRow(
                  s: s,
                  icon: Icons.engineering_outlined,
                  label: 'Sponsored vendors',
                ),
                _dividerLine(s),
                _menuRow(
                  s: s,
                  icon: Icons.receipt_long_outlined,
                  label: 'Recent Report',
                ),
                _dividerLine(s),
                _menuRow(
                  s: s,
                  icon: Icons.add_location_alt_outlined,
                  label: 'Location',
                ),
                _dividerLine(s),
                _menuRow(
                  s: s,
                  icon: Icons.inventory_2_outlined,
                  label: 'Clear cashe',
                ),
                _dividerLine(s),

                InkWell(
                  onTap: () async {
                    await TokenStore().clear();
                    Navigator.of(context, rootNavigator: true)
                        .pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (route) => false,
                    );
                  },
                  child: _menuRow(
                    s: s,
                    label: 'Log out',
                    gradientIcon: true,
                  ),
                ),
                _dividerLine(s),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _dividerLine(double s) => Container(
        height: 1,
        color: _divider,
      );

  static Widget _menuRow({
    required double s,
    String label = '',
    IconData? icon,
    bool gradientIcon = false,
  }) {
    final leftIcon = gradientIcon
        ? Container(
            width: 24 * s,
            height: 24 * s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _chipGrad,
            ),
            child:
                Icon(Icons.logout_rounded, size: 14 * s, color: Colors.white),
          )
        : Icon(icon, size: 22 * s, color: _title);

    return SizedBox(
      height: 58 * s,
      child: Row(
        children: [
          leftIcon,
          SizedBox(width: 14 * s),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 16 * s,
                fontWeight: FontWeight.w600,
                color: _title,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 22 * s, color: Colors.black.withOpacity(.75)),
        ],
      ),
    );
  }

  static void _openEditProfileSheet(
    BuildContext context, {
    required double s,
    required String firstName,
    required String lastName,
    required String phone,
    required String profileImage,
  }) {
    final fnCtrl = TextEditingController(text: firstName);
    final lnCtrl = TextEditingController(text: lastName);
    final phoneCtrl = TextEditingController(text: phone);
    final imgCtrl = TextEditingController(text: profileImage);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final loading =
                  state.updateProfileStatus == UpdateProfileStatus.loading;

              InputDecoration dec(String label, IconData icon) {
                return InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Edit Profile",
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: fnCtrl,
                    decoration: dec("First Name", Icons.person_outline),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lnCtrl,
                    decoration: dec("Last Name", Icons.person_outline),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: dec("Phone", Icons.phone_outlined),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: imgCtrl,
                    decoration: dec("Profile Image URL", Icons.link_outlined),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: loading
                          ? null
                          : () {
                              context.read<AuthBloc>().add(
                                    UpdateUserDetailsRequested(
                                      firstName: fnCtrl.text,
                                      lastName: lnCtrl.text,
                                      phone: phoneCtrl.text,
                                      profileImage: imgCtrl.text,
                                    ),
                                  );
                              Navigator.pop(context); // close sheet
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A7CFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Save Changes",
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}




// class ProfilePage extends StatelessWidget {
//   const ProfilePage({super.key});

//   static const _bg = Color(0xFFF6F7FB);
//   static const _title = Color(0xFF111111);
//   static const _sub = Color(0xFF7D8790);
//   static const _divider = Color(0xFFE9ECF2);

//   static const _chipGrad = LinearGradient(
//     colors: [Color(0xFF73D1FF), Color(0xFF6A7CFF)],
//     begin: Alignment.topLeft,
//     end: Alignment.bottomRight,
//   );

//   @override
//   Widget build(BuildContext context) {
//     // Reference width like iPhone (390 logical points)
//     final s = MediaQuery.of(context).size.width / 390.0;

//     return Scaffold(
//       backgroundColor: _bg,
//       body: SafeArea(
//         child: ListView(
//           padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 24 * s),
//           children: [
//             // ===== Header (back + centered title)
//             SizedBox(
//               height: 44 * s,
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                      Text(  'Profile',
//                      style: TextStyle(
//                       letterSpacing: 1.0,
//                        fontFamily: 'ClashGrotesk',
//                        fontSize: 24 * s,
//                        fontWeight: FontWeight.w600,
//                        color: Color(0xFF111111))),
             
//                   // Text(
//                   //   'Profile',
//                   //   style: TextStyle(
//                   //     fontFamily: 'ClashGrotesk',
//                   //     fontSize: 20 * s,
//                   //     fontWeight: FontWeight.w700,
//                   //     color: _title,
//                   //   ),
//                   // ),
//                 ],
//               ),
//             ),
//             SizedBox(height: 14 * s),

//             // ===== Top: Avatar + Name + Edit Profile
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 // Avatar with subtle rim + camera badge
//                 SizedBox(
//                   width: 96 * s,
//                   height: 96 * s,
//                   child: Stack(
//                     children: [
//                       Container(
//                         width: 96 * s,
//                         height: 96 * s,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           gradient: const LinearGradient(
//                             colors: [Color(0xFFEDEFF3), Colors.white],
//                             begin: Alignment.topLeft,
//                             end: Alignment.bottomRight,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(.06),
//                               blurRadius: 16 * s,
//                               offset: Offset(0, 8 * s),
//                             ),
//                           ],
//                         ),
//                         child: Padding(
//                           padding: EdgeInsets.all(3 * s),
//                           child: ClipOval(
//                             child: Image.asset(
//                               // <<< replace with your asset path
//                               'assets/avatar.png',
//                               fit: BoxFit.cover,
//                               width: 90 * s,
//                               height: 90 * s,
//                             ),
//                           ),
//                         ),
//                       ),
//                       Positioned(
//                         right: 4 * s,
//                         bottom: 4 * s,
//                         child: Container(
//                           width: 24 * s,
//                           height: 24 * s,
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             shape: BoxShape.circle,
//                             border: Border.all(color: _divider),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(.08),
//                                 blurRadius: 8 * s,
//                                 offset: Offset(0, 3 * s),
//                               ),
//                             ],
//                           ),
//                           child: Icon(Icons.photo_camera_outlined,
//                               size: 14 * s, color: _title),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(width: 14 * s),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                                     "${context.read<AuthBloc>().state.profile!.firstName.toString() + context.read<AuthBloc>().state.profile!.lastName.toString()}",//'William David',
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           fontSize: 20 * s,
//                           fontWeight: FontWeight.w700,
//                           color: _title,
//                         ),
//                       ),
//                       SizedBox(height: 4 * s),
//                       Text(
//                         '@${context.read<AuthBloc>().state.profile!.email.toString()}',
//                         style: TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           fontSize: 14 * s,
//                           fontWeight: FontWeight.w600,
//                           color: _sub,
//                         ),
//                       ),
//                       SizedBox(height: 10 * s),
//                       Align(
//                         alignment: Alignment.centerLeft,
//                         child: Container(
//                           height: 40 * s,
//                           padding: EdgeInsets.symmetric(horizontal: 16 * s),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(12 * s),
//                             gradient: _chipGrad,
//                             boxShadow: [
//                               BoxShadow(
//                                 color:
//                                     const Color(0xFF6A7CFF).withOpacity(.20),
//                                 blurRadius: 12 * s,
//                                 offset: Offset(0, 6 * s),
//                               ),
//                             ],
//                           ),
//                           alignment: Alignment.center,
//                           child: Text(
//                             'Edit Profile',
//                             style: TextStyle(
//                               fontFamily: 'ClashGrotesk',
//                               fontSize: 14.5 * s,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             SizedBox(height: 18 * s),
//             _dividerLine(s),

//             // ===== Menu rows (exact labels as in design)
//             _menuRow(
//               s: s,
//               icon: Icons.engineering_outlined,
//               label: 'Sponsored vendors',
//             ),
//             _dividerLine(s),
//             _menuRow(
//               s: s,
//               icon: Icons.receipt_long_outlined,
//               label: 'Recent Report',
//             ),
//             _dividerLine(s),
//             _menuRow(
//               s: s,
//               icon: Icons.add_location_alt_outlined,
//               label: 'Location',
//             ),
//             _dividerLine(s),
//             _menuRow(
//               s: s,
//               icon: Icons.inventory_2_outlined,
//               label: 'Clear cashe', // keep spelling to match screenshot
//             ),
//             _dividerLine(s),

//             // Logout row with gradient left icon
//             InkWell(
//               onTap: ()async{
//                 await TokenStore().clear();
//                 Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
//   MaterialPageRoute(builder: (_) => const AuthScreen()),
//   (route) => false,
// );
//               },
//               child: _menuRow(
//                 s: s,
//                 label: 'Log out',
//                 gradientIcon: true,
//               ),
//             ),
//             _dividerLine(s),
//           ],
//         ),
//       ),
//     );
//   }

//   static Widget _dividerLine(double s) => Container(
//         height: 1,
//         color: _divider,
//       );

//   static Widget _menuRow({
//     required double s,
//     String label = '',
//     IconData? icon,
//     bool gradientIcon = false,
//   }) {
//     final leftIcon = gradientIcon
//         ? Container(
//             width: 24 * s,
//             height: 24 * s,
//             decoration: const BoxDecoration(
//               shape: BoxShape.circle,
//               gradient: _chipGrad,
//             ),
//             child: Icon(Icons.logout_rounded,
//                 size: 14 * s, color: Colors.white),
//           )
//         : Icon(icon, size: 22 * s, color: _title);

//     return SizedBox(
//       height: 58 * s,
//       child: Row(
//         children: [
//           leftIcon,
//           SizedBox(width: 14 * s),
//           Expanded(
//             child: Text(
//               label,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 16 * s,
//                 fontWeight: FontWeight.w600,
//                 color: _title,
//               ),
//             ),
//           ),
//           Icon(Icons.chevron_right_rounded,
//               size: 22 * s, color: Colors.black.withOpacity(.75)),
//         ],
//       ),
//     );
//   }
// }
