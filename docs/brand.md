Absolutely. The feedback is crystal clear and leads to a much stronger, more user-friendly design. Removing the jarring animations in favor of in-place state changes creates the stability and calm focus we're aiming for.

This revised brand guide formalizes the "Educational Zen" aesthetic, using the visual design as the new ground truth.

---

### **Momentum: Brand & Design Guidelines**

### **Core Concept: The Sanctuary for Intentional Work**

Momentum is not merely a tool; it is a space. It is a digital sanctuary where users can quiet the noise, ground themselves in the present, and engage in deep, meaningful work. Our brand identity must reflect this by creating a sense of calm, control, and clarity, enabling the user to build and sustain creative velocity.

---

### 1. Brand Pillars

These four pillars are the foundation of our product and design philosophy. Every decision should be measured against them.

*   **Pillar 1: The Ritual of Preparation**
    *   **Principle:** We believe that great work begins before the work itself. The "Grounding Ritual" is the most important part of the process. Our design must elevate this preparation from a chore to a respected, calming ceremony.
    *   **Keywords:** Grounding, Stillness, Presence, Ritual, Deliberate.

*   **Pillar 2: The Clarity of Intention**
    *   **Principle:** The user's goal is the sacred focus. Our interface must be radically minimalist, removing every possible distraction to create a clear path between the user and their intention. The UI serves the goal, not the other way around.
    *   **Keywords:** Clarity, Focus, Essentialism, Uncluttered, Purpose.

*   **Pillar 3: The Sanctuary of Focus**
    *   **Principle:** The active session is a protected space. The design must create a feeling of a serene, private study—a sanctuary from the chaos of the digital world. The user should feel that the app is holding space for them to do their best work.
    *   **Keywords:** Sanctuary, Calm, Flow, Uninterrupted, Protection.

*   **Pillar 4: The Cycle of Insight**
    *   **Principle:** We are an educational tool for self-improvement. The reflection and analysis phase is not a logbook but a source of insight. The design should guide the user to learn from their process, fostering a cycle of continuous growth.
    *   **Keywords:** Insight, Growth, Reflection, Evolution, Self-Awareness.

---

### 2. Key Emotions to Evoke

A user interacting with Momentum should feel:

*   **Centered:** Grounded and present, as if they've just taken a meditative breath.
*   **Clear:** Free from mental clutter, with their intention sharply in focus.
*   **Composed:** In a state of calm control, fully prepared for the task at hand.
*   **Capable:** Confident in their ability to achieve their goal within this structured environment.
*   **Supported:** Gently guided by a system that respects their process and intelligence.

---

### 3. Phrases & Vocabulary

The language of the application is a core part of the user experience. It should be aspirational, respectful, and serene.

| Instead Of... | Use... | Rationale |
| :--- | :--- | :--- |
| "Set a Goal" | "Compose Your Intention" | Evokes thoughtfulness and creativity over task management. |
| "Checklist" | "Grounding Ritual" | Elevates a to-do list into a meaningful, preparatory act. |
| "Start Focus" | "Enter Sanctuary" | Frames the work session as entering a special, protected space. |
| "Time" | "Minutes" or "Duration" | More specific and tool-like where appropriate. |
| "Productivity" | "Focus," "Flow," "Presence" | Shifts the focus from output to the quality of attention. |

The brand voice is that of a wise, minimalist guide. It is encouraging but not effusive, clear but not cold.

---

### 4. Visual Design Directives

The visual design must be a direct expression of our brand pillars. It is a calm, organic, and premium aesthetic that stands in stark contrast to typical "productivity tech."

*   **Color Palette: Organic & Warm**
    *   **Foundation:** A warm, off-white canvas (`#F9F7F4`) that feels like high-quality paper or a softly lit wall, reducing the harshness of a pure white screen.
    *   **Accent:** A single, muted, sophisticated gold (`#C79A2A`). This is not a flashy, techy gold. It represents value, quality, and gentle focus. It is used for key actions, highlights, and moments of completion.
    *   **Neutrals:** The borders and inactive states (`#E3DDD1`) are soft, low-contrast, and derived from the canvas color, ensuring they define structure without creating visual noise.
    *   **Text:** Primary text is a soft black (`#111111`) for readability without harshness. Completed/secondary text (`#6D4F1C`) is a desaturated brown-gold, creating a subtle, elegant hierarchy.

*   **Typography: Classic & Clear**
    *   **Headings & CTAs:** A classic serif font (**New York**). This choice is deliberate. It evokes a literary, timeless, and thoughtful quality—like a book or a journal. It's the "Zen" part of our brand.
    *   **Body & UI Text:** A clean, highly-legible sans-serif (**SF Pro**). This provides a modern, functional counterpoint for clarity in interactive elements. The "Educational" part of our brand.
    *   **Hierarchy:** Strictly minimal. A large serif title sets the intention, a small-caps label defines the section, and a simple body font provides the content.

*   **Layout & Spacing: A Breath of Fresh Air**
    *   **Whitespace is Paramount:** The design uses generous padding and space to create a feeling of calm and order. The layout should never feel cramped or dense.
    *   **Centered & Symmetric:** The core layout is centered, creating a sense of balance and stability, reinforcing the "grounded" pillar.
    *   **Simplicity:** Each screen presents only what is necessary for the current step. There are no competing elements.

*   **Components & Iconography: Elegant & Tactile**
    *   **Style:** Components use soft, rounded rectangles and thin strokes. They feel light and approachable. They should feel less like computer UI and more like high-quality physical stationery.
    *   **Interaction:** Hover and press states are subtle and confirmatory, using soft fills (`#FDF9F1`) and accent strokes. The feeling should be of touching a responsive, quality object.
    *   **Checkboxes:** The custom checkbox design (a simple square that fills with a checkmark) is a key brand element. It's a small moment of satisfying, quiet feedback.

*   **Animation & Motion: Graceful Confirmation**
    *   **The Rule:** Motion must be subtle and confirmatory, never distracting. Layout shifts should be minimized.
    *   **Checklist Interaction:**
        *   Upon completion, a checklist row **does not collapse or move.**
        *   The visual state changes **in-place**: the border animates to `AccentGold`, the background softly fills with `GoldFill(hover)`, the checkbox fills, and the text gains a strikethrough. This provides a clear sense of accomplishment while maintaining layout stability.
    *   **Transitions:** Use gentle cross-fades (`.transition(.opacity)`) between major application states.
    *   **Micro-interactions:** Buttons and interactive elements should use subtle scale or color changes on hover and press to feel responsive, governed by an `interactiveSpring` to feel natural. There are no extraneous animations.