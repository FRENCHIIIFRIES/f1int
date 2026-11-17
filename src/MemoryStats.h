#pragma once

#include <QHash>

// Private memory (bytes) of the browser process and every helper process it started
// (Chromium renderers, GPU, network...), keyed by process id. Private memory is what
// the process holds for itself, the same number Chrome's task manager calls "memory footprint".
QHash<qint64, qint64> processTreeMemory();
