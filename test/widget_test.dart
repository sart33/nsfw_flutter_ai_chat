import 'package:flutter_test/flutter_test.dart';
import 'package:nsfw_chat/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const NsfwChatApp());
    expect(find.text('NSFW Chat'), findsOneWidget);
  });
}
