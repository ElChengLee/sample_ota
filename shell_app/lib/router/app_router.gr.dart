// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i5;
import 'package:flutter/material.dart' as _i6;
import 'package:shell_app/pages/dev_shell_page.dart' as _i1;
import 'package:shell_app/pages/home_page.dart' as _i2;
import 'package:shell_app/pages/mini_app_page.dart' as _i3;
import 'package:shell_app/pages/native_mini_app_page.dart' as _i4;

/// generated route for
/// [_i1.DevShellPage]
class DevShellRoute extends _i5.PageRouteInfo<void> {
  const DevShellRoute({List<_i5.PageRouteInfo>? children})
    : super(DevShellRoute.name, initialChildren: children);

  static const String name = 'DevShellRoute';

  static _i5.PageInfo page = _i5.PageInfo(
    name,
    builder: (data) {
      return const _i1.DevShellPage();
    },
  );
}

/// generated route for
/// [_i2.HomePage]
class HomeRoute extends _i5.PageRouteInfo<void> {
  const HomeRoute({List<_i5.PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static _i5.PageInfo page = _i5.PageInfo(
    name,
    builder: (data) {
      return const _i2.HomePage();
    },
  );
}

/// generated route for
/// [_i3.MiniAppPage]
class MiniAppRoute extends _i5.PageRouteInfo<MiniAppRouteArgs> {
  MiniAppRoute({
    _i6.Key? key,
    required String appId,
    String? initialPath,
    List<_i5.PageRouteInfo>? children,
  }) : super(
         MiniAppRoute.name,
         args: MiniAppRouteArgs(
           key: key,
           appId: appId,
           initialPath: initialPath,
         ),
         rawPathParams: {'appId': appId},
         rawQueryParams: {'path': initialPath},
         initialChildren: children,
       );

  static const String name = 'MiniAppRoute';

  static _i5.PageInfo page = _i5.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final queryParams = data.queryParams;
      final args = data.argsAs<MiniAppRouteArgs>(
        orElse: () => MiniAppRouteArgs(
          appId: pathParams.getString('appId'),
          initialPath: queryParams.optString('path'),
        ),
      );
      return _i3.MiniAppPage(
        key: args.key,
        appId: args.appId,
        initialPath: args.initialPath,
      );
    },
  );
}

class MiniAppRouteArgs {
  const MiniAppRouteArgs({this.key, required this.appId, this.initialPath});

  final _i6.Key? key;

  final String appId;

  final String? initialPath;

  @override
  String toString() {
    return 'MiniAppRouteArgs{key: $key, appId: $appId, initialPath: $initialPath}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MiniAppRouteArgs) return false;
    return key == other.key &&
        appId == other.appId &&
        initialPath == other.initialPath;
  }

  @override
  int get hashCode => key.hashCode ^ appId.hashCode ^ initialPath.hashCode;
}

/// generated route for
/// [_i4.NativeMiniAppPage]
class NativeMiniAppRoute extends _i5.PageRouteInfo<NativeMiniAppRouteArgs> {
  NativeMiniAppRoute({
    _i6.Key? key,
    required String appId,
    List<_i5.PageRouteInfo>? children,
  }) : super(
         NativeMiniAppRoute.name,
         args: NativeMiniAppRouteArgs(key: key, appId: appId),
         rawPathParams: {'appId': appId},
         initialChildren: children,
       );

  static const String name = 'NativeMiniAppRoute';

  static _i5.PageInfo page = _i5.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<NativeMiniAppRouteArgs>(
        orElse: () =>
            NativeMiniAppRouteArgs(appId: pathParams.getString('appId')),
      );
      return _i4.NativeMiniAppPage(key: args.key, appId: args.appId);
    },
  );
}

class NativeMiniAppRouteArgs {
  const NativeMiniAppRouteArgs({this.key, required this.appId});

  final _i6.Key? key;

  final String appId;

  @override
  String toString() {
    return 'NativeMiniAppRouteArgs{key: $key, appId: $appId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NativeMiniAppRouteArgs) return false;
    return key == other.key && appId == other.appId;
  }

  @override
  int get hashCode => key.hashCode ^ appId.hashCode;
}
