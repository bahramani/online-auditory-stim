# Online Auditory Stim

Online Auditory Stim is a MATLAB-based toolkit for presenting auditory stimuli while recording neural and event-aligned responses in real time. The project includes:

- An interactive UI-driven stimulator workflow.
- A lightweight continuous (“bare”) stimulator for direct WAV playback.
- Utilities for event detection and PSTH/raster visualization support.

The code is intended for lab environments using Blackrock/Cerebus acquisition hardware in addition to standard audio interfaces.

## Key Features

- **Session-based auditory stimulation** with configurable stimulus sets and repetition counts.
- **Two operation modes**:
  - `neural-stim`: stimulus presentation synchronized with Blackrock continuous/event data.
  - `behave-stim`: playback/recording mode using local audio hardware.
- **Automatic per-session logging** of event timing and neuron spike timestamps.
- **Randomized trial ordering** across selected audio files.
- **Saved event metadata** (`events-info.mat`) for downstream analysis.

## Repository Layout

- `rev1_12/runme.m` — main launcher for the UI-based stimulator.
- `rev1_12/audio_stimulator.m` — primary stimulation app logic.
- `rev1_12/audio_stim_ui.mlapp` — App Designer UI definition.
- `rev1_12/+birdslab/` — package utilities (event detection, plotting, Blackrock config, audio event model).
- `rev1_12/bare_stim_launcher.m` — launcher for the simplified continuous stim player.
- `rev1_12/response_plotter.m` — plotting utility script.

## Requirements

- **MATLAB** (App Designer + DSP/System Toolbox functionality used in code).
- **Audio Toolbox / DSP System Toolbox** components used by:
  - `audioDeviceReader`
  - `audioDeviceWriter`
  - `dsp.AudioFileReader`
  - `dsp.AudioFileWriter`
- **Blackrock Cerebus SDK (`cbmex`)** for `neural-stim` workflows.
- A local dataset layout containing:
  - A folder of stimulus `.wav` files.
  - A sessions output directory.

## Quick Start

### 1) Configure paths and channels

Edit `rev1_12/runme.m`:

- `songs_folder` — path to your stimulus audio files.
- `trials_folder` — path where session outputs are stored.
- `spikes_channel` — neural spike channel index.
- `audio_channel` — analog/event channel index.
- `cont_data_fs` — acquisition sampling rate (Hz).
- `operation_mode` — `'neural-stim'` or `'behave-stim'`.

### 2) Launch

From MATLAB:

```matlab
run('rev1_12/runme.m')
```

If `operation_mode` is `neural-stim`, the script initializes Blackrock (`birdslab.config_black_rock`) before launching and closes `cbmex` when done.

### 3) Run a session in the UI

- Select one or more stimuli in the file tree.
- Set repeat count and timing controls.
- Start stimulation.
- Stop stimulation to finalize logs.

Session outputs are written under:

```text
<trials_folder>/<yyyy-mm-dd>/<session_name>/
```

with files such as:

- `trial-events.txt`
- `trial-neurons.txt`
- `events-info.mat`
- `rec.wav` (in `behave-stim` mode)

## Bare Continuous Stimulator

For a simplified non-UI continuous stimulus flow, use:

```matlab
run('rev1_12/bare_stim_launcher.m')
```

Update configuration values in that script (`cont_stims_folder`, `cont_stim_id`, channels, and sample rate) before running.

## Notes and Operational Guidance

- The Blackrock SDK path in `+birdslab/config_black_rock.m` is currently hardcoded and should be adapted for your system.
- Use Windows-style path separators in MATLAB scripts as currently written.
- Ensure acquisition and audio devices are available before launching stimulation.

https://colab.research.google.com/drive/1TMBtYU8vSztmx2b2Uc54R0u0NNbooZmh?invite=CLKAragM

## License

This project is licensed under the terms in `LICENSE`.
