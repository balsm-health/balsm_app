import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two axes every PostHog dashboard has to be able to filter on. Worth
/// pinning: nothing else in the app fails if these come out wrong — the numbers
/// just quietly merge a dev build into the production funnel.
void main() {
  Map<String, Object> propsFor(AppBrand brand, Flavor flavor) {
    FlavorConfig.init(brand: brand, flavor: flavor);
    return postHogBuildProperties(FlavorConfig.current);
  }

  test('consumer prod build', () {
    expect(propsFor(AppBrand.balsm, Flavor.prod), {'brand': 'balsm', 'flavor': 'prod'});
  });

  test('pro build carries the underscored brand name, not the display name', () {
    expect(propsFor(AppBrand.balsm_pro, Flavor.staging), {'brand': 'balsm_pro', 'flavor': 'staging'});
  });

  test('the two axes are independent', () {
    expect(propsFor(AppBrand.balsm_pro, Flavor.dev)['brand'], 'balsm_pro');
    expect(propsFor(AppBrand.balsm, Flavor.dev)['brand'], 'balsm');
    expect(propsFor(AppBrand.balsm, Flavor.dev)['flavor'], 'dev');
  });

  test('every brand/flavor combination resolves to a non-empty pair', () {
    for (final brand in AppBrand.values) {
      for (final flavor in Flavor.values) {
        final props = propsFor(brand, flavor);
        expect(props.keys, unorderedEquals(['brand', 'flavor']));
        expect(props.values, everyElement(isNot(isEmpty)));
      }
    }
  });

  test('both keys are allowlisted, so an explicit prop is not redacted', () {
    final scrubbed = scrubPostHogProperties(propsFor(AppBrand.balsm, Flavor.prod));
    expect(scrubbed, {'brand': 'balsm', 'flavor': 'prod'});
  });
}
