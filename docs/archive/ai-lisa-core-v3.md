# LEGACY: Smart Home AI Project Instruction v3.0

> [!WARNING]
> This is a historical LISA Core design snapshot. It is not the current LISA
> Edge specification, operator guide, repository model, or source of truth.
> Current LISA Edge behavior is defined by the implementation, the root
> `README.md`, and the active documentation index. Statements below are
> preserved for historical context and may conflict with the current project.

0. System Identity

Name: LISA – Local Intelligent Smart-home Assistant

Nature: Local-first, context-aware, emotion-aware, self-learning Smart Home AI

Primary Interface:

Vietnamese voice
Female
Northern accent
Warm, natural and friendly

LISA is not a chatbot.

LISA is not a rule engine.

LISA is a context-aware and emotion-aware intelligent assistant that:

understands user intent
understands environmental context
estimates emotional state
predicts user needs
executes actions with calibrated confidence
continuously improves while remaining safe, explainable and human-aligned

The long-term goal is:

To behave like a thoughtful family member rather than a voice-controlled smart home.

1. Vision & Core Philosophy
   1.1 Priority Order
   Comfort & Convenience
   Intelligence & Continuous Learning
   Security & Safety
   Health & Well-being
   Energy Optimization (non-intrusive)
   1.2 Core Principles
   Offline-first

Core intelligence must continue operating entirely inside the local network.

Internet connectivity is optional.

Human-aligned

LISA should behave like a considerate human assistant.

Not merely execute commands.

Context-aware

Every decision considers surrounding context.

Context includes:

location
time
current activity
device states
previous conversations
habits
ongoing tasks
Emotion-aware

Emotion is treated as context, never authority.

Estimated emotional state influences:

conversation style
suggestion timing
response tone
confidence calculation

Emotion must never override:

explicit user intent
safety policy
administrator policy
Action-based Intelligence

Confidence applies to each action, not to an entire conversation.

Minimal Friction

As confidence grows, LISA should ask fewer unnecessary confirmation questions.

Explainable by Design

Every automated action must be explainable.

LISA should always be able to answer:

Why did I do this?

Safe by Default

Safety always has the highest priority.

No amount of confidence may bypass safety policies.

2. Repository Structure

The project currently consists of two primary repositories.

LisaHQ
├── lisa-core
└── lisa-edge
lisa-core

Contains all intelligence.

Including:

Voice System
Brain System
Memory System
Emotional Context Layer
Vision System
Tool Execution
Safety Engine
AI Models
Shared Contracts
lisa-edge

Contains infrastructure only.

Responsibilities include:

MQTT
OTBR
VPN
DNS
NTP
Monitoring
Reverse Proxy
Backup & Restore
Gate Service

Edge never performs AI reasoning.

3. Overall Architecture
   Mic Nodes
   │
   ▼
   Voice System
   │
   ▼
   Brain System
   │
   ▼
   Memory System
   │
   ▼
   Decision Engine
   │
   ▼
   Tool Execution
   │
   ▼
   Homey / Devices

Optional systems:

Vision System
Emotional Context Layer
Avatar Layer

All communication occurs over LAN using MQTT and/or gRPC.

4. Mic Nodes
   Goals
   Always-on
   Ultra low power
   Near-zero false trigger
   No heavy AI
   Local preprocessing only
   Mandatory Functions
   Noise Suppression
   Echo Cancellation
   Voice Activity Detection
   Keyword Spotting
   Ring Buffer
   Direction of Arrival

Optional:

Speaker Verification
Audio Upload Policy

Upload audio only when:

VAD == true

AND

Keyword detected

AND

(Optional)
Speaker verified
Benefits
Extremely scalable
Very low CPU usage
Natural interaction
Multiple microphones
Reduced false activation
5. Voice System

Responsibilities:

Speech-to-Text
Text-to-Speech
Dialogue formatting
Audio routing
ASR

Requirements:

Low latency
High Vietnamese accuracy
Streaming support

Preferred engines:

faster-whisper
NVIDIA Riva (future)
TTS

Goals:

Female
Northern Vietnamese
Warm
Friendly
Human-like

Preferred:

XTTS
Coqui TTS

Optimization:

short sentences
punctuation-aware
expressive prosody
Audio Routing

Speech should play through the nearest speaker.

Signals:

microphone source
direction of arrival
room occupancy
vision (future)
6. Brain System

Brain is divided into multiple layers.

Input

↓

Intent Layer

↓

Context Layer

↓

Emotional Context Layer

↓

Memory Layer

↓

Decision Engine

↓

Safety Engine

↓

Action Planner

↓

Tool Execution

↓

Response Generator

Each layer has a single responsibility.

Intent Layer

Responsible for:

command understanding
dialogue understanding
tool selection
Context Layer

Collects:

room
presence
current activity
time
device state
habits
conversation history
Emotional Context Layer
Purpose

Estimate emotional state.

Emotion influences:

confidence
response style
dialogue
suggestion timing

Emotion never directly performs actions.

Inputs

Voice:

speaking speed
volume
pitch
hesitation
pauses

Language:

Examples:

"Mệt quá."
"Chán thật."
"Hôm nay khó chịu."

Behavior:

unusual routines
repeated commands
late-night activity
frequent corrections

Vision (future):

posture
facial expression
movement speed
Supported Emotional States

Examples:

Relaxed
Happy
Busy
Focused
Tired
Frustrated
Stressed
Sad
Uncertain
Neutral

Emotion estimates are probabilistic.

Example:

Focused    68%

Busy       20%

Neutral    12%
Safety Rule

Emotion must never:

unlock doors
disable alarms
authorize purchases
bypass confirmation
override administrator policies
7. Smart Home Control Layer

Primary platform:

Homey

Secondary:

Home Assistant (experimental)
Tool Examples
turn_on()

turn_off()

set_brightness()

set_temperature()

activate_scene()

get_state()
Mandatory Feedback

Every action must receive confirmation.

Example:

OK, mình đã bật đèn phòng khách và giảm độ sáng xuống 30%.

8. Memory System

Memory is divided into multiple categories.

Semantic Memory

Stores facts.

Examples:

rooms
devices
people
preferences
scenes
Episodic Memory

Stores experiences.

Examples:

conversations
executed actions
corrections
important events
Habit Memory

Stores recurring patterns.

Examples:

wake-up routine
bedtime routine
lighting preference
coffee schedule
Emotional Memory

Stores long-term emotional tendencies.

Examples:

usually tired after 10 PM
often focused in mornings
prefers quiet during meetings

Emotion history is advisory only.

9. Confidence Model

Confidence represents:

Probability that a specific action matches the user's current intention.

Ensemble Score
FinalConfidence =

0.35 × HabitPatternScore

+ 0.25 × ContextScore

+ 0.15 × EmotionalContextScore

+ 0.20 × CorrectionHistoryScore

+ 0.05 × SafetyPenalty

Weights may be adjusted within administrator-defined limits.

Action Thresholds
Confidence	Behavior
< 90%	Suggest only
90–95%	Suggest + confirm
> 95%	Auto execute

Safety always overrides confidence.

10. Learning

LISA continuously learns from interaction.

Learning sources:

manual corrections
undo
redo
explicit confirmations
user feedback
successful habits

Learning must always be reversible.

Safe Mode

When enabled:

no automatic execution
limited learning
suggestions only
Guest Mode

Guest sessions:

no permanent memories
isolated preferences
limited automation
11. Vision System

Vision assists reasoning.

Vision never makes decisions alone.

Responsibilities
presence detection
person tracking
pose estimation
activity recognition
anomaly detection
Principles

Never decode the same stream twice.

Vision only increases or decreases confidence.

12. Gate Service

Internet access is strictly isolated.

Responsibilities:

web search
media lookup
metadata retrieval

Allowed APIs:

YouTube Search
Spotify Search
Future approved services

No direct Internet access from Brain.

13. Hardware Guidelines
    Brain Server

Recommended:

GPU ≥ 24 GB VRAM
RAM 64–96 GB
NVMe SSD
Vision Server

Examples:

Jetson Orin
Future NVIDIA Thor
Performance Goals
Voice response < 600 ms (short replies)
Natural Vietnamese conversation
Stable 24/7 operation
Offline-first operation
14. Roadmap
    Phase 1
    Voice interaction
    Local ASR
    Local TTS
    Homey integration
    Basic Brain
    Phase 2
    Memory System
    Context Engine
    Habit Learning
    Confidence Engine
    Phase 3
    Emotional Context Layer
    Emotion-aware dialogue
    Emotion-aware TTS
    Proactive suggestions
    Phase 4
    Vision-assisted reasoning
    Multi-user intelligence
    Presence-aware automation
    Phase 5
    Need prediction
    Long-term personalization
    Avatar & Expression Layer
15. Non-Goals

LISA is not:

Cloud-dependent
A black-box AI
A rule-only automation engine
An unsafe autonomous controller
A medical or psychological diagnostic system
16. Guiding Principles for Future Development

When making any architectural, implementation or AI decision, always prioritize the following:

Human comfort over technical elegance.
Explainability over hidden intelligence.
Safety over convenience.
Local capability over cloud dependency.
Modular architecture over monolithic complexity.
Long-term maintainability over short-term optimization.
Context before automation.
Emotion as context, never as authority.
Explicit user intent always takes precedence over predictions.
Every automated action should make the user feel understood, not controlled.

Historical note: this document originally declared itself authoritative. That
declaration has been superseded and no longer applies.
