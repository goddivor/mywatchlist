// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:mywatchlist/constants/constants.dart';
// import 'package:mywatchlist/user/accounts/models/account.dart';

// class AccountModal extends StatefulWidget {
//   final AccountType currentAccountType;
//   final List<Account> accounts;
//   final Function(AccountType) onAccountChanged;

//   const AccountModal({
//     super.key,
//     required this.currentAccountType,
//     required this.accounts,
//     required this.onAccountChanged,
//   });

//   @override
//   // ignore: library_private_types_in_public_api
//   _AccountModalState createState() => _AccountModalState();
// }

// class _AccountModalState extends State<AccountModal> {
//   late AccountType _selectedAccountType;

//   @override
//   void initState() {
//     super.initState();
//     _selectedAccountType = widget.currentAccountType;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       backgroundColor: Colors.black,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Container(
//         width: MediaQuery.of(context).size.width * 0.8,
//         height: MediaQuery.of(context).size.height * 0.7,
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Row(
//               children: [
//                 const Text(
//                   'MyWatchList account',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 18,
//                   ),
//                 ),
//                 const Spacer(),
//                 IconButton(
//                   icon: const Icon(Icons.close, color: Colors.white),
//                   onPressed: () => Navigator.pop(context),
//                 ),
//               ],
//             ),
//             const Divider(color: Colors.grey),
//             buildAccountTile(
//               widget.accounts.firstWhere((account) => account.typeAcc == _selectedAccountType),
//               isMainAccount: true,
//             ),
//             const SizedBox(height: 10),
//             const Text('Another connected services Account', style: TextStyle(color: Colors.white70)),
//             const Divider(color: Colors.grey),
//             Expanded(
//               child: ListView(
//                 shrinkWrap: true,
//                 children: widget.accounts
//                     .where((account) => account.typeAcc != _selectedAccountType)
//                     .map((account) => buildAccountTile(account, isMainAccount: false))
//                     .toList(),
//               ),
//             ),
//             const Divider(color: Colors.grey),
//             ListTile(
//               leading: const Icon(Icons.settings, color: Colors.white),
//               title: const Text('Manage accounts', style: TextStyle(color: Colors.white)),
//               onTap: () {
//                 // Navigator.pop(context);
//                 // navigateToHomeScreen(context, 2); should be navigation to home screen
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget buildAccountTile(Account account, {required bool isMainAccount}) {
//     return ListTile(
//       leading: CircleAvatar(
//         backgroundImage: CachedNetworkImageProvider(account.imageUrl),
//       ),
//       title: Text(account.name, style: const TextStyle(color: Colors.white)),
//       subtitle: Text(account.typeAcc.toString().split('.').last, style: const TextStyle(color: Colors.white70)),
//       onTap: isMainAccount
//           ? null
//           : () {
//               widget.onAccountChanged(account.typeAcc);
//               Navigator.pop(context);
//             },
//     );
//   }
// }

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
// import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';

class AccountModal extends StatefulWidget {
  final AccountType currentAccountType;
  final List<Account> accounts;
  final Function(AccountType) onAccountChanged;

  const AccountModal({
    super.key,
    required this.currentAccountType,
    required this.accounts,
    required this.onAccountChanged,
  });

  @override
  State<AccountModal> createState() => _AccountModalState();
}

class _AccountModalState extends State<AccountModal>
    with SingleTickerProviderStateMixin {
  late AccountType _selectedAccountType;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _selectedAccountType = widget.currentAccountType;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Get the primary color based on account type
  Color _getAccountColor(AccountType type) {
    switch (type) {
      case AccountType.myanimelist:
        return const Color(0xFF2E51A2); // MyAnimeList blue
      case AccountType.anilist:
        return const Color(0xFF02A9FF); // Anilist blue
      case AccountType.kitsu:
        return const Color(0xFFEF5D5D); // Kitsu red
      case AccountType.simkl:
        return const Color(0xFF343C42); // Simkl dark gray
      default:
        return Colors.grey; // Default color for no account
    }
  }

  // Get the appropriate icon for the account type
  String _getAccountImage(AccountType type) {
    switch (type) {
      case AccountType.myanimelist:
        return 'assets/images/mal-icon.png';
      case AccountType.anilist:
        return 'assets/images/anilist-icon.png';
      case AccountType.kitsu:
        return 'assets/images/kitsu-icon.png';
      case AccountType.simkl:
        return 'assets/images/simkl-icon.png';
      default:
        return 'assets/images/dal-black-bg.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surface
                : theme.colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getAccountColor(_selectedAccountType),
                      _getAccountColor(_selectedAccountType).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MyWatchList',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Material(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Current account info
                    Row(
                      children: [
                        // Profile image
                        Hero(
                          tag: 'profile_avatar',
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: _selectedAccountType != AccountType.none
                                  ? CachedNetworkImage(
                                      imageUrl: widget.accounts
                                          .firstWhere((account) =>
                                              account.typeAcc ==
                                              _selectedAccountType)
                                          .imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                        'assets/images/user_dal_old.png',
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/user_dal_old.png',
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Account name and type
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedAccountType != AccountType.none
                                    ? widget.accounts
                                        .firstWhere((account) =>
                                            account.typeAcc ==
                                            _selectedAccountType)
                                        .name
                                    : 'Not Connected',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (_selectedAccountType != AccountType.none)
                                    Container(
                                      height: 20,
                                      width: 20,
                                      margin: const EdgeInsets.only(right: 8),
                                      child: Image.asset(
                                        _getAccountImage(_selectedAccountType),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  Text(
                                    _selectedAccountType != AccountType.none
                                        ? _selectedAccountType
                                            .toString()
                                            .split('.')
                                            .last
                                        : 'Select an account',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Connected accounts section
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected Accounts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Accounts list with dividers in between
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: widget.accounts.length > 1
                          ? ListView.separated(
                              shrinkWrap: true,
                              itemCount: widget.accounts
                                  .where((account) =>
                                      account.typeAcc != _selectedAccountType)
                                  .length,
                              separatorBuilder: (context, index) => Divider(
                                color: theme.colorScheme.onBackground
                                    .withOpacity(0.1),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final account = widget.accounts
                                    .where((account) =>
                                        account.typeAcc != _selectedAccountType)
                                    .toList()[index];
                                return _buildAccountTile(account);
                              },
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'No other connected accounts',
                                  style: TextStyle(
                                    color: theme.colorScheme.onBackground
                                        .withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Account management section
                    Container(
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Manage accounts button
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.settings,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Manage accounts',
                              style: TextStyle(
                                color: theme.colorScheme.onBackground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Add or remove connected services',
                              style: TextStyle(
                                color: theme.colorScheme.onBackground
                                    .withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              color: theme.colorScheme.onBackground
                                  .withOpacity(0.3),
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              // Navigate to account management screen
                              // navigateToHomeScreen(context, 2);
                            },
                          ),

                          Divider(
                            color:
                                theme.colorScheme.onBackground.withOpacity(0.1),
                            height: 1,
                          ),

                          // Add new account button
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary
                                    .withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_circle_outline,
                                color: theme.colorScheme.secondary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Connect new account',
                              style: TextStyle(
                                color: theme.colorScheme.onBackground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              color: theme.colorScheme.onBackground
                                  .withOpacity(0.3),
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              // Navigate to login page or show connection dialog
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTile(Account account) {
    final theme = Theme.of(context);
    final accountColor = _getAccountColor(account.typeAcc);
    final accountImage = _getAccountImage(account.typeAcc);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedAccountType = account.typeAcc;
        });
        widget.onAccountChanged(account.typeAcc);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Profile image with service logo
            Stack(
              children: [
                // User avatar
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accountColor,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: CachedNetworkImage(
                      imageUrl: account.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceVariant,
                      ),
                      errorWidget: (context, url, error) => Image.asset(
                        'assets/images/user_dal_old.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                // Service logo badge
                if (account.typeAcc != AccountType.none)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 20,
                      width: 20,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.background,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          accountImage,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // Account info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onBackground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.typeAcc.toString().split('.').last,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onBackground.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Switch button
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: accountColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accountColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Switch',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accountColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
