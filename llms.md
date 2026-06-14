# Marp Guide — Combined Reference (llms.md)

> Compiled from the Marp guide documentation at
> <https://github.com/marp-team/marp/tree/main/website/docs/guide>.
> All eight guide pages are concatenated below in a logical reading order.
> Relative links (`/docs/...`, `/assets/...`) have been rewritten to absolute
> `https://marp.app/...` URLs so this file stands alone.
>
> Note: `marp` code fences (```` ```markdown:marp ````) in the source are live
> rendered previews on the website; here they are kept as plain Markdown
> examples.

## Table of contents

1. [How to write slides](#how-to-write-slides)
2. [Directives](#directives)
3. [Image syntax](#image-syntax)
4. [Fragmented list](#fragmented-list)
5. [Fitting header](#fitting-header)
6. [Heading divider](#heading-divider)
7. [Math typesetting](#math-typesetting)
8. [Theme](#theme)

---

# How to write slides

## Markdown

To write slides using Marp, you have to know basic Markdown syntax. It doesn't take long to learn the basics, and there are many Markdown tutorials on the internet, so this guide will focus on the additional syntax used by Marp that allows you to write slides.

### Resources for learning Markdown

- **[Markdown Guide](https://www.markdownguide.org/)** - A simple guide on how to use Markdown
- **[Markdown Tutorial](https://www.markdowntutorial.com/)** - Step-by-step Markdown tutorials with interactive exercises

## Slides

OK, let's write presentation slides. Marp splits slides in the deck using the horizontal ruler (e.g. `---`).

```markdown
# Slide 1

Hello, world!

---

# Slide 2

Marp splits slides in the deck by horizontal ruler.
```

If you use the `---` ruler, an empty line may be required before the ruler by [the spec of CommonMark](https://spec.commonmark.org/0.29/#example-28). If you do not want to add empty lines around the ruler, you can also use the underline ruler `___`, asterisk ruler `***`, or space-included ruler `- - -` to split slides.

> This feature is inherited from [Marpit framework](https://marpit.marp.app/markdown).

## Syntaxes

Marp's Markdown syntax is based on [CommonMark](https://commonmark.org/). In addition, Marp uses some extended syntax:

- Line breaks in a paragraph will convert to `<br />` tag automatically.
  - You also can use `<br />` tag directly (Useful if you need a line break within a [fitting header](https://marp.app/docs/guide/fitting-header)).
- There is special meaning in some (uncommon) list markers `*` and `1)`. [▶️ Fragmented list](https://marp.app/docs/guide/fragmented-list).
- Some extended syntaxes that came from [GitHub Flavored Markdown (GFM)](https://guides.github.com/features/mastering-markdown/#GitHub-flavored-markdown) are enabled:
  - [Automatic linking for URLs](https://github.github.com/gfm/#autolinks-extension-)
  - Emoji shortcode (provided by [markdown-it-emoji](https://github.com/markdown-it/markdown-it-emoji) and [twemoji](https://github.com/twitter/twemoji))
  - [Strikethrough](https://github.github.com/gfm/#strikethrough-extension-) (`~~strike~~`)
  - Syntax highlighting for code blocks (via [highlight.js](https://highlightjs.org/))
  - [Tables](https://github.github.com/gfm/#tables-extension-)
- Most HTML tags are _disabled_ by default for security reasons. Marp only allows users to use two tags by default: the `<style>` tag for tweaking the theme and the `<br />` tag mentioned earlier.
  - To enable all HTML tags, you need to opt-in for the Marp tool you are using.

> Many extended syntaxes are inherited from [Marp Core](https://github.com/marp-team/marp-core).

---

# Directives

Marp has an extended syntax called **"Directives"** to control theme, page number, header, footer, and other slide elements.

> The syntax of directives is inherited from [Marpit framework](https://marpit.marp.app/directives). Please note that different directives are used by each Marp tool.

## Usage

Marp parses directives as [YAML](https://yaml.org/).

### HTML comment

```markdown
<!--
theme: default
paginate: true
-->
```

### Front matter

Like many tools (e.g. [Jekyll site generator](https://jekyllrb.com/docs/front-matter/)), Marp uses **YAML front matter**. Directives can be defined in front matter.

YAML front matter must be at the beginning of a Markdown document and enclosed by dashed rulers.

```markdown
---
theme: default
paginate: true
---
```

Note that the dashed ruler is also used to indicate where Marp should [split slides](https://marp.app/docs/guide/how-to-write-slides#slides). Marp uses the first two dashed rulers to indicate YAML front matter. Subsequent dashed rulers indicate slide breaks.

> TIP: Defining directives in the front matter is equivalent to setting the directives using an HTML comment on the first page. Suppose your favorite Markdown editor does not support the front matter syntax. In that case, you can safely define the directive in an HTML comment instead.

## Type of directives

There are two types of Marp directives:

- **Global directives** - Controlling settings for the all slides (e.g. `theme`, `size`)
- **Local directives** - Controlling setting values for one slide (e.g. `paginate`, `header`, `footer`)

You can define both directives in the same way. You can mix definitions too. The only difference is that some settings apply to all slides, and some apply to only one slide.

### Global directives

**Global directives** are settings for the entire slide deck.

| Name             | Description                                                                    |
| ---------------- | ------------------------------------------------------------------------------ |
| `theme`          | [Set a theme name for the slide deck ▶️](https://marp.app/docs/guide/theme)                    |
| `style`          | Specify CSS for tweaking theme                                                 |
| `headingDivider` | [Specify heading divider option ▶️](https://marp.app/docs/guide/heading-divider)               |
| `size`           | Choose the slide size preset provided by theme                                 |
| `math`           | [Choose a library to render math typesetting ▶️](https://marp.app/docs/guide/math-typesetting) |
| `title`          | Set a title of the slide deck                                                  |
| `author`         | Set an author of the slide deck                                                |
| `description`    | Set a description of the slide deck                                            |
| `keywords`       | Set comma-separated keywords for the slide deck                                |
| `url`            | Set canonical URL for the slide deck (for HTML export)                         |
| `image`          | Set Open Graph image URL (for HTML export)                                     |
| `marp`           | Set whether or not enable Marp feature in VS Code                              |

If you set the same global directive multiple times, Marp will use the last defined value.

### Local directives

**Local directives** are settings for a specific slide.

| Name                 | Description                                                                                                                               |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `paginate`           | Show page number on the slide if set to `true`                                                                         |
| `header`             | Specify the content of the slide header                                                                          |
| `footer`             | Specify the content of the slide footer                                                                          |
| `class`              | Set [HTML `class` attribute](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/class) for the slide element `<section>` |
| `backgroundColor`    | Set [`background-color` style](https://developer.mozilla.org/en-US/docs/Web/CSS/background-color) of the slide                            |
| `backgroundImage`    | Set [`background-image` style](https://developer.mozilla.org/en-US/docs/Web/CSS/background-image) of the slide                            |
| `backgroundPosition` | Set [`background-position` style](https://developer.mozilla.org/en-US/docs/Web/CSS/background-position) of the slide                      |
| `backgroundRepeat`   | Set [`background-repeat` style](https://developer.mozilla.org/en-US/docs/Web/CSS/background-repeat) of the slide                          |
| `backgroundSize`     | Set [`background-size` style](https://developer.mozilla.org/en-US/docs/Web/CSS/background-size) of the slide                              |
| `color`              | Set [`color` style](https://developer.mozilla.org/en-US/docs/Web/CSS/color) of the slide                                                  |

#### Inheritance

Slides will inherit setting values of local directives from the immediately previous slide **unless** a local directive is explicitly set for the current slide. In other words, defined local directives will apply to both the defined page and subsequent pages.

For example, the Markdown for this set of slides defines the `backgroundColor` directive on the second page. Because subsequent pages inherit local directives, the third page will also have the same color.

```markdown
# Page 1

Go to next page :arrow_right:

---

<!-- backgroundColor: lightblue -->

# Page 2

## This page has a light blue background.

---

# Page 3

## This page also has the same light blue background.
```

#### Scoped local directives

If you want a local directive to apply only to the current page, add the underscore prefix `_` to the name of directives.

The value of a scoped directive will be given priority over an inherited value, and subsequent pages will not inherit the value of the scoped directive.

```markdown
<!-- color: red -->

# Page 1

This page has red text.

---

<!-- _color: blue -->

# Page 2

This page has blue text, specified by a scoped local directive.

---

# Page 3

Go back to red text.
```

The underscore prefix can be added to any local directives.

#### Diagram

![The diagram of local directives and scoped directives](https://marp.app/assets/docs/directives.png 'The diagram of local directives and scoped directives')

## Page number

To add page number to the slide, set the **`paginate`** local directive to `true`.

```markdown
<!-- paginate: true -->

You can see the slide number in the lower right.
```

Refer to [theme guide](https://marp.app/docs/guide/theme) for details on how to style a slide number.

### Skip pagination in the title slide

Just move the definition of the `paginate` directive to the second slide.

```markdown
# Title slide

---

<!-- paginate: true --->

## Start pagination from this slide.
```

You can also use [scoped directive](#scoped-local-directives) to disable pagination in the title slide.

```markdown
---
paginate: true
_paginate: false
---

# Title slide

---

## Start pagination from this slide.
```

## Header and footer

Use **`header`** and **`footer`** local directives to add headers and footers to slides.

```markdown
<!--
header: Header content
footer: Footer content
-->

# Header and footer
```

Refer to [theme guide](https://marp.app/docs/guide/theme) for details on how to style header and footer.

### Markdown formatting

You can use inline Markdown formatting (italic, bold, inline image, etc) in header and footer like this:

```markdown
---
header: '**bold** _italic_'
footer: '![image](https://example.com/image.jpg)'
---
```

To make directives parsable as valid YAML, you can wrap content with (double-)quotes.

### Reset header and footer

Set the value of a directive to an empty string value to reset the header and footer in the middle of the slide deck.

```markdown
---
header: '**Header**'
footer: '_Footer_'
---

# Example

---

<!--
header: ''
footer: ''
-->

## Reset header and footer
```

---

# Image syntax

> This feature is inherited from [Marpit framework](https://marpit.marp.app/image-syntax).
> See the Marpit documentation for the full image syntax (resizing, background
> images, filters, and grid backgrounds): <https://marpit.marp.app/image-syntax>.

---

# Fragmented list

Marp uses some uncommon list markers to denote a **fragmented list** (also known as an incremental list or builds), which allows list content to appear incrementally.

Fragmented lists are _only available if you export to HTML_. If you export to PDF and PPTX, the fragmented list will be rendered as a normal list.

> Be careful when using fragmented lists. While fragmented lists can help focus the audience's attention on the last displayed item, they may also create confusion about hidden items. Some articles recommend never using builds (e.g. [Presentation Rules](http://www.jilles.net/perma/2020/06/05/presentation-rules.html)).

## For bullet lists

CommonMark's bullet list markers are `-`, `+`, and `*` (https://spec.commonmark.org/0.29/#bullet-list-marker). If you use `*` as the marker, Marp will parse the list as a fragmented list.

```markdown
# Bullet list

- One
- Two
- Three

---

# Fragmented list

* One
* Two
* Three
```

## For ordered list

CommonMark's [ordered list marker](https://spec.commonmark.org/0.29/#ordered-list-marker) must have `.` or `)` after digits. If you use `)` as the following character, then Marp will parse the ordered list as a fragmented list.

```markdown
# Ordered list

1. One
2. Two
3. Three

---

# Fragmented list

1) One
2) Two
3) Three
```

> These are inherited from [Marpit framework](https://marpit.marp.app/fragmented-list).
>
> [This syntax only indicates that the list _should_ be fragmented](https://marpit.marp.app/fragmented-list?id=rendering). If the tools integrated with Marp do nothing with the syntax, this list would be rendered as a normal list. In the official toolset, [Marp CLI](https://github.com/marp-team/marp-cli)'s default HTML template `bespoke` can reproduce a fragmented list as a build animation.

---

# Fitting header

When the `<!--fit-->` comment is placed in a heading, the heading will be scaled to fit onto a single line.

```markdown
# <!-- fit --> Fitting header
```

The syntax is similar to [Deckset's `[fit]` keyword](https://docs.decksetapp.com/English.lproj/Formatting/01-headings.html), but Marp uses an HTML comment to hide the keyword when the Markdown is rendered.

> This feature is inherited from [Marp Core](https://github.com/marp-team/marp-core).

## Examples

### Takahashi-style

You can efficiently make [Takahashi-style](https://en.wikipedia.org/wiki/Takahashi_method) slides like the [Big](https://github.com/tmcw/big) presentation system by using the fitting header. Combining fitting headers with the [heading divider](https://marp.app/docs/guide/heading-divider) directive will allow you to write one slide per line.

```markdown
---
theme: uncover
headingDivider: 1
---

# <!--fit--> Takahashi-style<br />presentation

# <!--fit--> Feature

# <!--fit--> Huge text

# <!--fit--> A few words
```

---

# Heading divider

The heading divider directive tells Marp to automatically add a slide break before a heading of the specified level. This directive is particularly useful when converting an existing Markdown document to slides.

Heading dividers is similar to [Pandoc](https://pandoc.org/)'s [`--slide-level` option](https://pandoc.org/MANUAL.html#structuring-the-slide-show) and [Deckset 2](https://www.deckset.com/2/)'s "Slide Dividers" option.

> This feature is inherited from the [Marpit framework](https://marpit.marp.app/directives?id=heading-divider).

## Example

Let's say you have a Markdown document like this:

```markdown
# Markdown document

The article of Markdown

## What is Markdown?

> Markdown is a lightweight markup language for creating formatted text using a plain-text editor.
>
> _-- https://en.wikipedia.org/wiki/Markdown_

## History

### Origin

Markdown has created by John Gruber in 2004.

https://daringfireball.net/projects/markdown/

### Standardization

CommonMark is a project for a standardization of Markdown launched in 2012.
```

Add the [`headingDivider` global directive](https://marp.app/docs/guide/directives#global-directives).

```markdown
<!-- headingDivider: 2 -->
```

Once you have specified the directive, Marp will automatically split the document into slides by starting a new slide whenever a section has a heading level of 2.

The `headingDivider` global directive accepts heading levels from 1 to 6. When the heading level is set as a number, Marp will split slides at headings that are _at the specified level and at all parent levels_. So, `headingDivider: 2` will actually make new slides at headings of levels 1 and 2.

If a section has so much content that it overflows the slide, it might be better to split it by subsection. To do that, just change the base level for `headingDivider` to `3`.

> [Rulers to split pages](https://marp.app/docs/guide/how-to-write-slides#slides) still work normally even if enabled `headingDivider`.

## Advanced

Auto split in parent heading levels is reasonable behavior in most cases, but sometimes you may require finer control of splitting levels. If you set the directive value to an array, you also instruct Marp to split at only the specified levels.

```markdown
<!-- headingDivider: [1, 3] -->
```

This setting will instruct Marp to split slides at heading levels 1 and 3.

---

# Math typesetting

[Many Markdown tools support math rendering](https://github.com/cben/mathdown/wiki/math-in-markdown). We have [Pandoc's Markdown style](https://pandoc.org/MANUAL.html#math) math typesetting support. Marp renders math using [MathJax](https://www.mathjax.org/) (or, alternatively, [KaTeX](https://katex.org/)).

### Inline math

Surround your formula with a single dollar character `$...$`.

```markdown
Render inline math such as $ax^2+bc+c$.
```

### Math block

Surround the formula with double dollar characters `$$...$$`. Math in the block element will render with centering. The math in the block element will also scale down automatically if it is sticking out from the horizontal border of the slide (only in supported themes).

```markdown
$$ I_{xx}=\int\int_Ry^2f(x,y)\cdot{}dydx $$

$$
f(x) =
  \int_{-\infty}^\infty
  \hat f(\xi)\,e^{2 \pi i \xi x}
  \,d\xi
$$
```

> This feature is inherited from [Marp Core](https://github.com/marp-team/marp-core).

## MathJax

By default, Marp uses **[MathJax](https://www.mathjax.org/)** to render math typesetting.

### Declare to use MathJax

Set [`math` global directive](https://marp.app/docs/guide/directives#global-directives) as `mathjax`.

```markdown
---
math: mathjax
---

Render inline math such as $ax^2+bc+c$.
```

For the determined rendering of slide, we recommend always to declare math library to use in the slide. No definition of math directive may bring inconsistent rendering result depending on the version of Marp Core.

## KaTeX

**[KaTeX](https://katex.org/)** is an alternative library to render math typesettings in Marp, and it was former default.

By defining `math` global directive as `katex`, you can continue to render math with KaTeX.

### Enable KaTeX

Set [`math` global directive](https://marp.app/docs/guide/directives#global-directives) as `katex`.

```markdown
---
math: katex
---

Render inline math such as $ax^2+bc+c$.
```

### Define global macro

In KaTeX rendering, macros defined by `\def` will persist only in a local math environment. To persist defined macro for subsequent math environments in Markdown, use `\gdef` (`\global\def`) instead.

```markdown
$$
% macroA can use only in this math block.
\def\macroA{{\color{red}A}}

% macroB has defined globally so you can use it after here.
\gdef\macroB{{\color{blue}B}}

\macroA + \macroB
$$

---

$$
% macroA cannot use, but macroB can.
\macroA + \macroB
$$
```

[See the detail of supported macro functions in KaTeX documentation](https://katex.org/docs/supported.html#macros).

### Configuration

KaTeX options can be configured in [Marp Core's constructor option](https://github.com/marp-team/marp-core#constructor-options). You should use [Marp CLI](https://github.com/marp-team/marp-cli) if you need to set a custom configuration in Marp conversion.

```javascript
// marp.config.js
module.exports = {
  options: {
    math: {
      lib: 'katex',
      katexFontPath: 'https://example.com/assets/katex-fonts/'
      katexOption: {
        errorColor: '#ff0000',
        macros: {
          '\\RR': '\\mathbb{R}',
        },
      },
    },
  },
}
```

```bash
marp -c marp.config.js marp-math.md
```

[See the details of KaTeX option in the documentation.](https://katex.org/docs/options.html)

### mhchem extension

[mhchem](https://mhchem.github.io/MathJax-mhchem/) is an extension for writing chemical equations. To enable mhchem in Marp, you should use a Marp CLI configuration file and follow [a guide of KaTeX for Node.js](https://katex.org/docs/node.html#using-mhchem-extension).

```javascript
// marp.config.js
const katex = require('katex')
require('katex/dist/contrib/mhchem.js') // modify katex module
```

```bash
marp -c marp.config.js marp-mhchem.md
```

A common mistake is [using a client-side `<script>` to load the extension](https://github.com/KaTeX/KaTeX/tree/master/contrib/mhchem#usage). _This will not work because Marp's rendering will be completed within Node.js, not the browser._ See also: [marp-team/marp#99](https://github.com/marp-team/marp/discussions/99)

### Known issues for KaTeX rendering

- KaTeX rendering requires fetching Web Fonts from [jsDelivr](https://www.jsdelivr.com/) CDN. If you are in offline or the limited network by proxy, the slide may not render math.
- Safari does not shrink down the big math block rendered by KaTeX. ([marp-team/marp-core#159](https://github.com/marp-team/marp-core/issues/159))
- Rendering of `\tag{}` is incompatible with the math block. ([marp-team/marp-core#236](https://github.com/marp-team/marp-core/issues/236))

---

# Theme

> This page is a stub in the upstream documentation. Themes let you change the
> visual design of the slide deck. Set one with the `theme` global directive
> (e.g. `default`, `gaia`, `uncover`) and customize via the `style` directive or
> custom CSS.
>
> See the live theme documentation: <https://marp.app/docs/guide/theme>
> and the built-in theme sources: <https://github.com/marp-team/marp-core/tree/main/themes>
