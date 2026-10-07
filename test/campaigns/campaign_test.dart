import 'package:ecocuajimalpa/features/campaigns/data/campaign.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Campaign campaign = Campaign.fromJson(<String, dynamic>{
    'id': 3,
    'title': 'Reciclatón',
    'description': 'Trae tus electrónicos',
    'location': 'Explanada',
    'colony': 'Cuajimalpa Centro',
    'category': 'Reciclaje',
    'starts_at': '2026-10-10T16:00:00Z',
    'ends_at': '2026-10-10T22:00:00Z',
    'participants_count': 14,
  }, joined: true);

  test('fromJson lee la campaña y el contador de participantes', () {
    expect(campaign.title, 'Reciclatón');
    expect(campaign.participantsCount, 14);
    expect(campaign.joined, isTrue);
  });

  test('isHappeningAt respeta el inicio y el fin', () {
    expect(campaign.isHappeningAt(DateTime.utc(2026, 10, 10, 15, 59)), isFalse);
    expect(campaign.isHappeningAt(DateTime.utc(2026, 10, 10, 16)), isTrue);
    expect(campaign.isHappeningAt(DateTime.utc(2026, 10, 10, 22)), isFalse);
  });

  test('copyWith cambia solo lo indicado', () {
    final Campaign left = campaign.copyWith(
      joined: false,
      participantsCount: 13,
    );

    expect(left.joined, isFalse);
    expect(left.participantsCount, 13);
    expect(left.title, campaign.title);
  });
}
