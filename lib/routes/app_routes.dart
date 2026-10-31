import 'package:flutter/material.dart';
import 'package:ren_tracker/features/authentication/login_screen.dart';
import 'package:ren_tracker/features/dashboard/admin_home.dart';
import 'package:ren_tracker/features/dashboard/employee_home.dart';
import 'package:ren_tracker/features/dashboard/super_admin_home.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String superAdminHome = '/super_admin_home';
  static const String adminHome = '/admin_home';
  static const String employeeHome = '/employee_home';

  static Map<String, WidgetBuilder> get routes => {
    login: (ctx) => const LoginScreen(),
    superAdminHome: (ctx) => const SuperAdminHome(),
    adminHome: (ctx) => const AdminHome(),
    employeeHome: (ctx) => const EmployeeHome(),
  };
}

