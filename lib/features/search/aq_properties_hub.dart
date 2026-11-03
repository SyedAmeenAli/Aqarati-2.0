import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/localization/flow_strings.dart';
import '../workspace/aq_action_card.dart';
import '../workspace/aq_home.dart';

/// The Properties landing page: Buy, Rent, Sell with Aqary e-Broker and My Favorites. It sits
/// inside the customer shell, so the four-tab bar stays in place.
class AQPropertiesHubScreen extends StatelessWidget {
  const AQPropertiesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    AQActionCard card(String icon, String key, String image, String path) => AQActionCard(
      icon: icon,
      image: image,
      title: f.t('hub.$key'),
      sub: f.t('hub.$key.s'),
      onTap: () => context.push(path),
    );
    return aqPage(
      context,
      hero: AQHero(
        image: 'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg',
        title: f.t('hub.title'),
        sub: f.t('hub.sub'),
        onBack: () => aqBack(context, '/app/home'),
      ),
      children: [
        AQSectionHeader(f.t('home.browse'), help: true),
        AQActionGrid(
          cards: [
            card('home', 'buy', 'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg', '/properties/categories?tx=buy'),
            card('calendar', 'rent', 'assets/properties/p5/03_Contemporary_apartment_property_.jpg', '/properties/categories?tx=rent'),
          ],
        ),
        const SizedBox(height: AQSpacing.x4),
        // Selling is its own destination: a full-width card, not a fourth tile.
        AQBanner(
          image: 'assets/location/09_Modern_villa_exterior_in_Seeb.jpg',
          eyebrow: f.t('hub.sell.eyebrow'),
          title: f.t('hub.sell.t'),
          body: f.t('hub.sell.b'),
          cta: f.t('hub.sell.cta'),
          onTap: () => context.push('/sell'),
        ),
        const SizedBox(height: AQSpacing.x4),
        AQActionGrid(
          cards: [
            card('bookmark', 'fav', 'assets/location/10_Muscat_corniche_at_warm_evening.jpg', '/saved'),
          ],
        ),
      ],
    );
  }
}
