import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_beer_rain/catch_game.dart';

void main() {
  test('time of day defaults to dusk and is fixed during a round', () {
    final g = CatchGame()..lane = true;
    expect(g.timeOfDay, StageTime.dusk);
    expect(g.selectTime(StageTime.night), true);
    g.start();
    expect(g.selectTime(StageTime.day), false);
    g.phase = Phase.playing;
    expect(g.selectTime(StageTime.day), false);
    expect(g.timeOfDay, StageTime.night);
    g.phase = Phase.result;
    expect(g.selectTime(StageTime.day), true);
    expect(g.inspect()['timeOfDay'], 'day');
  });
}
