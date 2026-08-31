import {existsSync, readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, join} from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(
  readFileSync(join(here, '..', 'src', 'edit-manifest.json'), 'utf8'),
);
const duration = manifest.composition.durationInFrames;
const publicDir = join(here, '..', 'public');

const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message);
  }
};

const validateRange = (item, label) => {
  assert(Number.isInteger(item.startFrame), `${label}.startFrame must be an integer`);
  assert(Number.isInteger(item.endFrame), `${label}.endFrame must be an integer`);
  assert(
    item.startFrame >= 0 && item.startFrame < item.endFrame && item.endFrame <= duration,
    `${label} is outside the ${duration}-frame composition`,
  );
};

for (const [index, segment] of manifest.timeline.entries()) {
  const label = `timeline[${index}]`;
  validateRange(segment, label);
  assert(segment.kind === 'video', `${label}.kind must be video`);
  assert(
    Number.isInteger(segment.sourceStartFrame),
    `${label}.sourceStartFrame must be an integer`,
  );
  const sourceEnd =
    segment.sourceStartFrame + segment.endFrame - segment.startFrame;
  assert(
    segment.sourceStartFrame >= 0,
    `${label}.sourceStartFrame must be non-negative`,
  );
  assert(
    sourceEnd <= manifest.sourceDurationInFrames,
    `${label} ends at source frame ${sourceEnd}, after source frame ${manifest.sourceDurationInFrames}`,
  );
}

for (const [index, card] of manifest.questionCards.entries()) {
  validateRange(card, `questionCards[${index}]`);
  assert(
    typeof card.text === 'string' && card.text.length > 0,
    `questionCards[${index}].text is empty`,
  );
}

for (const [index, caption] of manifest.captions.entries()) {
  validateRange(caption, `captions[${index}]`);
  assert(
    typeof caption.text === 'string' && caption.text.length > 0,
    `captions[${index}].text is empty`,
  );
  if (index > 0) {
    assert(
      caption.startFrame >= manifest.captions[index - 1].endFrame,
      `captions[${index}] overlaps captions[${index - 1}]`,
    );
  }
}

for (const [index, caption] of manifest.irodoriCaptions.entries()) {
  validateRange(caption, `irodoriCaptions[${index}]`);
  assert(
    typeof caption.text === 'string' && caption.text.length > 0,
    `irodoriCaptions[${index}].text is empty`,
  );
  if (index > 0) {
    assert(
      caption.startFrame >= manifest.irodoriCaptions[index - 1].endFrame,
      `irodoriCaptions[${index}] overlaps irodoriCaptions[${index - 1}]`,
    );
  }
}

assert(
  existsSync(join(publicDir, manifest.ambientBed.src)),
  `ambient bed not found: ${manifest.ambientBed.src}`,
);
assert(
  typeof manifest.ambientBed.volume === 'number' &&
    manifest.ambientBed.volume >= 0 &&
    manifest.ambientBed.volume <= 1,
  'ambientBed.volume must be from 0 to 1',
);

for (const [index, clip] of manifest.irodoriAudio.entries()) {
  const label = `irodoriAudio[${index}]`;
  validateRange(clip, label);
  assert(existsSync(join(publicDir, clip.src)), `${label}.src not found: ${clip.src}`);
  assert(
    typeof clip.volume === 'number' && clip.volume >= 0 && clip.volume <= 1,
    `${label}.volume must be from 0 to 1`,
  );
  assert(
    manifest.timeline.some(
      (segment) =>
        segment.startFrame > 0 &&
        clip.startFrame >= segment.startFrame &&
        clip.endFrame <= segment.endFrame,
    ),
    `${label} must fit wholly inside one answer video segment`,
  );
}

validateRange(manifest.openingTitle, 'openingTitle');
validateRange(manifest.lowerThird, 'lowerThird');
validateRange(manifest.outro, 'outro');
assert(
  manifest.outro.endFrame === duration,
  'outro must end on the final composition frame',
);

const occupied = new Uint8Array(duration);
const occupy = (range, label) => {
  for (let frame = range.startFrame; frame < range.endFrame; frame++) {
    assert(
      occupied[frame] === 0,
      `${label} overlaps the base timeline at frame ${frame}`,
    );
    occupied[frame] = 1;
  }
};
manifest.timeline.forEach((item, index) => occupy(item, `timeline[${index}]`));
manifest.questionCards.forEach((item, index) =>
  occupy(item, `questionCards[${index}]`),
);
occupy(manifest.outro, 'outro');
assert(
  occupied.every((value) => value === 1),
  'base timeline contains uncovered frames',
);

console.log(
  `Valid project manifest: ${duration} frames, ${manifest.timeline.length} video segments, ` +
    `${manifest.questionCards.length} question cards, ${manifest.captions.length} Wan captions, ` +
    `${manifest.irodoriAudio.length} Irodori clips`,
);
