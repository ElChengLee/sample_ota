// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i4;
import 'package:flutter/material.dart' as _i5;
import 'package:shell_app/pages/home_page.dart' as _i1;
import 'package:shell_app/pages/mini_app_page.dart' as _i2;
import 'package:shell_app/pages/native_mini_app_page.dart' as _i3;

/// generated route for
/// [_i1.HomePage]
class HomeRoute extends _i4.PageRouteInfo<void> {
  const HomeRoute({List<_i4.PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static _i4.PageInfo page = _i4.PageInfo(
    name,
    builder: (data) {
      return const _i1.HomePage();
    },
  );
}

/// generated route for
/// [_i2.MiniAppPage]
class MiniAppRoute extends _i4.PageRouteInfo<MiniAppRouteArgs> {
  MiniAppRoute({
    _i5.Key? key,
    required String appId,
    String? initialPath,
    List<_i4.PageRouteInfo>? children,
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

  static _i4.PageInfo page = _i4.PageInfo(
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
      return _i2.MiniAppPage(
        key: args.key,
        appId: args.appId,
        initialPath: args.initialPath,
      );
    },
  );
}

class MiniAppRouteArgs {
  const MiniAppRouteArgs({this.key, required this.appId, this.initialPath});

  final _i5.Key? key;

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
/// [_i3.NativeMiniAppPage]
class NativeMiniAppRoute extends _i4.PageRouteInfo<NativeMiniAppRouteArgs> {
  NativeMiniAppRoute({
    _i5.Key? key,
    required String appId,
    List<_i4.PageRouteInfo>? children,
  }) : super(
         NativeMiniAppRoute.name,
         args: NativeMiniAppRouteArgs(key: key, appId: appId),
         rawPathParams: {'appId': appId},
         initialChildren: children,
       );

  static const String name = 'NativeMiniAppRoute';

  static _i4.PageInfo page = _i4.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<NativeMiniAppRouteArgs>(
        orElse: () =>
            NativeMiniAppRouteArgs(appId: pathParams.getString('appId')),
      );
      return _i3.NativeMiniAppPage(key: args.key, appId: args.appId);
    },
  );
}

class NativeMiniAppRouteArgs {
  const NativeMiniAppRouteArgs({this.key, required this.appId});

  final _i5.Key? key;

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
