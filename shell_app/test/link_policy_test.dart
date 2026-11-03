import 'package:flutter_test/flutter_test.dart';
import 'package:shell_app/navigation/link_policy.dart';

void main() {
  const shop = LinkPolicy(canOpen: {'mini_game', 'mini_native'}, openableBy: {'*'}, exported: {'/', '/product/*'});
  const game = LinkPolicy(openableBy: {'mini_shop'});
  const native = LinkPolicy(canOpen: {'mini_shop', 'mini_game'}, openableBy: {'mini_shop'});
  const policies = {'mini_shop': shop, 'mini_game': game, 'mini_native': native};

  String? check(LinkCaller caller, String target, {String? path, Map<String, LinkPolicy> config = policies}) =>
      checkLink(caller, targetId: target, path: path, policyOf: (id) => config[id] ?? LinkPolicy.none);

  group('matchPath', () {
    test('khớp chính xác, * một đoạn, ** phần còn lại', () {
      expect(LinkPolicy.matchPath('/', '/'), isTrue);
      expect(LinkPolicy.matchPath('/', '/product/p1'), isFalse);
      expect(LinkPolicy.matchPath('/product/*', '/product/p1'), isTrue);
      expect(LinkPolicy.matchPath('/product/*', '/product'), isFalse);
      expect(LinkPolicy.matchPath('/product/*', '/product/p1/review'), isFalse);
      expect(LinkPolicy.matchPath('/a/**', '/a'), isTrue);
      expect(LinkPolicy.matchPath('/a/**', '/a/b/c'), isTrue);
      expect(LinkPolicy.matchPath('/**', '/bat/ky/dau'), isTrue);
    });
  });

  group('checkLink giữa mini app', () {
    test('cả hai phía đồng ý thì được mở', () {
      expect(check(const MiniAppCaller('mini_shop'), 'mini_game'), isNull);
      expect(check(const MiniAppCaller('mini_shop'), 'mini_native'), isNull);
      expect(check(const MiniAppCaller('mini_native'), 'mini_shop', path: '/product/p2'), isNull);
    });

    test('phía gọi không khai báo canOpen thì bị chặn', () {
      expect(check(const MiniAppCaller('mini_game'), 'mini_shop'), contains('canOpen'));
    });

    test('phía bị gọi không cho (openableBy) thì bị chặn dù phía gọi có canOpen', () {
      expect(check(const MiniAppCaller('mini_native'), 'mini_game'), contains('openableBy'));
    });

    test('màn không exported thì bị chặn', () {
      expect(check(const MiniAppCaller('mini_shop'), 'mini_game', path: '/settings'), contains('exported'));
      expect(check(const MiniAppCaller('mini_native'), 'mini_shop', path: '/checkout'), contains('exported'));
    });

    test('điều hướng trong chính nó luôn được, kể cả màn không exported', () {
      expect(check(const MiniAppCaller('mini_game'), 'mini_game', path: '/settings'), isNull);
    });

    test('app không có trong config thì chặn mọi chiều', () {
      expect(check(const MiniAppCaller('mini_shop'), 'mini_game', config: {'mini_shop': shop}), contains('openableBy'));
      expect(check(const MiniAppCaller('x'), 'mini_shop'), contains('canOpen'));
    });

    test('đổi config là đổi kết quả, không cần gì khác', () {
      // Ví dụ: thêm mini_native vào openableBy của game trên server.
      final updated = {...policies, 'mini_game': const LinkPolicy(openableBy: {'mini_shop', 'mini_native'})};
      expect(check(const MiniAppCaller('mini_native'), 'mini_game', config: updated), isNull);
    });
  });

  group('checkLink từ Shell và hệ điều hành', () {
    test('Shell mở được mọi màn', () {
      expect(check(const ShellCaller(), 'mini_game', path: '/settings'), isNull);
    });

    test('hệ điều hành chỉ mở được màn exported, không cần openableBy', () {
      expect(check(const SystemCaller(), 'mini_game'), isNull);
      expect(check(const SystemCaller(), 'mini_shop', path: '/product/p2'), isNull);
      expect(check(const SystemCaller(), 'mini_game', path: '/settings'), isNotNull);
    });
  });

  test('fromJson/toJson giữ nguyên, thiếu khoá dùng mặc định an toàn', () {
    expect(LinkPolicy.fromJson(shop.toJson()), shop);
    expect(LinkPolicy.fromJson(null), LinkPolicy.none);
    expect(LinkPolicy.fromJson({'canOpen': ['a']}).exported, {'/'});
  });
}
