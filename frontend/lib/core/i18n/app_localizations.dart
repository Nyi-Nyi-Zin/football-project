import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('my'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return value ?? const AppLocalizations(Locale('en'));
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Betting App',
      'wallet': 'Wallet',
      'profile': 'Profile',
      'betting': 'Betting',
      'liveOdds': 'Live Odds',
      'withdraw': 'Withdraw',
      'totalBalance': 'Total Balance',
      'recentTransactions': 'Recent Transactions',
      'noTransactions': 'No transactions yet.',
      'errorLoadingTransactions': 'Error loading transactions',
      'funds': 'Funds',
      'amountMmk': 'Amount (MMK)',
      'cancel': 'Cancel',
      'successful': 'successful!',
      'failedCheckLimits': 'failed. Check limits/balance.',
      'welcomeBack': 'Welcome Back',
      'signInContinue': 'Sign in to continue betting',
      'email': 'Email',
      'password': 'Password',
      'signIn': 'Sign In',
      'dontHaveAccount': "Don't have an account? ",
      'signUp': 'Sign Up',
      'createAccount': 'Create Account',
      'joinAction': 'Join the action and start betting',
      'fullName': 'Full Name',
      'username': 'Username',
      'usernameRequired': 'Username is required',
      'min3Chars': 'Minimum 3 characters',
      'phoneOptional': 'Phone (optional)',
      'createAccountBtn': 'Create Account',
      'alreadyHaveAccount': 'Already have an account? ',
      'userDataNotFound': 'User data not found',
      'editProfile': 'Edit Profile',
      'phone': 'Phone',
      'saveProfile': 'Save Profile',
      'changePassword': 'Change Password',
      'currentPassword': 'Current Password',
      'newPassword': 'New Password',
      'confirmNewPassword': 'Confirm New Password',
      'changePasswordBtn': 'Change Password',
      'logout': 'Logout',
      'language': 'Language',
      'english': 'English',
      'myanmar': 'Myanmar',
      'theme': 'Theme',
      'lightMode': 'Light',
      'darkMode': 'Dark',
      'systemMode': 'System',
      'profileUpdated': 'Profile updated successfully',
      'passwordChanged': 'Password changed successfully',
      'newPasswordDifferent':
          'New password must be different from current password',
      'fullNameRequired': 'Full name is required',
      'currentPasswordRequired': 'Current password is required',
      'newPasswordRequired': 'New password is required',
      'passwordMinLength': 'Password must be at least 8 characters',
      'confirmPasswordRequired': 'Please confirm your new password',
      'passwordsNoMatch': 'Passwords do not match',
      'emailRequired': 'Email is required',
      'emailValid': 'Enter a valid email',
      'passwordRequired': 'Password is required',
      'noMatches': 'No matches available',
      'myBets': 'My Bets',
      'noBets': 'No bets yet',
    },
    'my': {
      'appTitle': 'လောင်းကစား အက်ပ်',
      'wallet': 'ပိုက်ဆံအိတ်',
      'profile': 'ပရိုဖိုင်',
      'betting': 'လောင်းကစား',
      'liveOdds': 'တိုက်ရိုက် Odds',
      'withdraw': 'ထုတ်ယူရန်',
      'totalBalance': 'စုစုပေါင်း လက်ကျန်',
      'recentTransactions': 'မကြာသေးမီ ငွေသွင်း/ထုတ်',
      'noTransactions': 'ငွေလုပ်ဆောင်မှု မရှိသေးပါ။',
      'errorLoadingTransactions': 'ငွေလုပ်ဆောင်မှုများ ဖတ်မရပါ',
      'funds': 'ငွေ',
      'amountMmk': 'ပမာဏ (MMK)',
      'cancel': 'ပယ်ဖျက်မည်',
      'successful': 'အောင်မြင်ပါသည်!',
      'failedCheckLimits': 'မအောင်မြင်ပါ။ ကန့်သတ်ချက်/လက်ကျန်ကို စစ်ပါ။',
      'welcomeBack': 'ပြန်လည်ကြိုဆိုပါတယ်',
      'signInContinue': 'ဆက်လောင်းရန် အကောင့်ဝင်ပါ',
      'email': 'အီးမေးလ်',
      'password': 'လျှို့ဝှက်နံပါတ်',
      'signIn': 'အကောင့်ဝင်မည်',
      'dontHaveAccount': 'အကောင့်မရှိသေးဘူးလား? ',
      'signUp': 'စာရင်းသွင်းမည်',
      'createAccount': 'အကောင့်ဖွင့်မည်',
      'joinAction': 'လောင်းကစားစတင်ရန် ဝင်ရောက်ပါ',
      'fullName': 'အမည်အပြည့်အစုံ',
      'username': 'အသုံးပြုသူအမည်',
      'usernameRequired': 'အသုံးပြုသူအမည် လိုအပ်သည်',
      'min3Chars': 'အနည်းဆုံး ၃ လုံးလိုအပ်သည်',
      'phoneOptional': 'ဖုန်း (မဖြည့်လည်းရ)',
      'createAccountBtn': 'အကောင့်ဖွင့်မည်',
      'alreadyHaveAccount': 'အကောင့်ရှိပြီးသားလား? ',
      'userDataNotFound': 'အသုံးပြုသူအချက်အလက် မတွေ့ပါ',
      'editProfile': 'ပရိုဖိုင်ပြင်မည်',
      'phone': 'ဖုန်း',
      'saveProfile': 'ပရိုဖိုင်သိမ်းမည်',
      'changePassword': 'လျှို့ဝှက်နံပါတ်ပြောင်းမည်',
      'currentPassword': 'လက်ရှိလျှို့ဝှက်နံပါတ်',
      'newPassword': 'လျှို့ဝှက်နံပါတ်အသစ်',
      'confirmNewPassword': 'အသစ်ကို ထပ်မံအတည်ပြုပါ',
      'changePasswordBtn': 'လျှို့ဝှက်နံပါတ်ပြောင်းမည်',
      'logout': 'ထွက်မည်',
      'language': 'ဘာသာစကား',
      'english': 'အင်္ဂလိပ်',
      'myanmar': 'မြန်မာ',
      'theme': 'အပြင်အဆင်',
      'lightMode': 'အလင်း',
      'darkMode': 'အမှောင်',
      'systemMode': 'စနစ်အလိုက်',
      'profileUpdated': 'ပရိုဖိုင်ပြင်ဆင်မှု အောင်မြင်ပါသည်',
      'passwordChanged': 'လျှို့ဝှက်နံပါတ်ပြောင်းခြင်း အောင်မြင်ပါသည်',
      'newPasswordDifferent': 'အသစ်သည် လက်ရှိနံပါတ်နှင့် မတူရပါ',
      'fullNameRequired': 'အမည်အပြည့်အစုံ လိုအပ်သည်',
      'currentPasswordRequired': 'လက်ရှိလျှို့ဝှက်နံပါတ် လိုအပ်သည်',
      'newPasswordRequired': 'လျှို့ဝှက်နံပါတ်အသစ် လိုအပ်သည်',
      'passwordMinLength': 'လျှို့ဝှက်နံပါတ် အနည်းဆုံး ၈ လုံးလိုအပ်သည်',
      'confirmPasswordRequired': 'အသစ်ကို ထပ်မံဖြည့်ပါ',
      'passwordsNoMatch': 'လျှို့ဝှက်နံပါတ် မတူညီပါ',
      'emailRequired': 'အီးမေးလ် လိုအပ်သည်',
      'emailValid': 'မှန်ကန်သော အီးမေးလ် ထည့်ပါ',
      'passwordRequired': 'လျှို့ဝှက်နံပါတ် လိုအပ်သည်',
      'noMatches': 'ပွဲစဉ် မရှိသေးပါ',
      'myBets': 'ကျွန်ုပ်၏ လောင်းမှုများ',
      'noBets': 'လောင်းမှု မရှိသေးပါ',
    },
  };

  String tr(String key) {
    final langCode = locale.languageCode;
    final current = _localizedValues[langCode] ?? _localizedValues['en']!;
    return current[key] ?? _localizedValues['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'my'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
