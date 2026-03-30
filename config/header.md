---
marp: true
size: 16:9
paginate: true
footer: "2026-03-23 | Statistics Canada | Statistique Canada"
header: ""
theme: default
style: |
  /* Statistics Canada Marp Theme */

  /* Import Inter font from Google Fonts */
  @import url("https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap");

  :root {
      /* Color variables */
      --primary-color: #26374a;
      /* Statistics Canada blue */
      --secondary-color: #ea5936;
      /* Statistics Canada orange */
      --accent-color: #3e6ca7;
      --light-gray: #f5f5f5;
      --dark-gray: #333;
      --text-color: #333;
      --background-color: #fff;

      /* Font variables */
      --main-font: sans-serif;
      --code-font: monospace;

      /* Size variables */
      --base-font-size: 12px;
      --h1-size: 1.5em;
      --h2-size: 1.3em;
      --h3-size: 1.1em;
      --p-size: 0.9em;
      --code-size: 0.8em;

      /* Spacing variables */
      --section-padding: 0.1rem;
      --element-margin: 0.6rem;
  }

  /* Apply the font to all elements */
  * {
      font-family: var(--main-font);
  }

  /* Top alignment for content */
  section {
      display: flex;
      flex-direction: column;
      justify-content: flex-start;
      padding-top: 2rem;
  }

  /* Header styles */
  h1 {
      font-size: var(--h1-size);
      font-weight: 600;
      margin-bottom: var(--element-margin);
      margin-top: 0;
  }

  h2 {
      font-size: var(--h2-size);
      font-weight: 500;
      margin-bottom: var(--element-margin);
      margin-top: 0;
  }

  h3 {
      font-size: var(--h3-size);
      font-weight: 500;
      margin-bottom: var(--element-margin);
      margin-top: 0;
  }

  h6 {
      margin-top: 0.1rem;
  }

  /* Paragraph styles */
  p {
      font-size: var(--p-size);
      line-height: 1.2;
      margin-bottom: var(--element-margin);
  }

  /* Code block styles */
  pre>code {
      font-family: var(--code-font);
      font-size: 0.6em;
      background-color: #f5f5f5;
      color: #2d2d2d;
      padding: 0.5rem;
      border-radius: 4px;
      line-height: 1.3;
      display: block;
      overflow-x: auto;
      border: 1px solid #ddd;
  }

  /* Syntax highlighting tokens - high contrast colors */
  pre>code .token.comment,
  pre>code .token.prolog,
  pre>code .token.doctype,
  pre>code .token.cdata {
      color: #6a9955;
  }

  pre>code .token.punctuation {
      color: #2d2d2d;
  }

  pre>code .token.property,
  pre>code .token.tag,
  pre>code .token.boolean,
  pre>code .token.number,
  pre>code .token.constant,
  pre>code .token.symbol {
      color: #0066cc;
  }

  pre>code .token.selector,
  pre>code .token.attr-name,
  pre>code .token.string,
  pre>code .token.char,
  pre>code .token.builtin {
      color: #a31515;
  }

  pre>code .token.operator,
  pre>code .token.entity,
  pre>code .token.url,
  pre>code .language-css .token.string,
  pre>code .style .token.string {
      color: #2d2d2d;
  }

  pre>code .token.atrule,
  pre>code .token.attr-value,
  pre>code .token.keyword {
      color: #0000ff;
  }

  pre>code .token.function,
  pre>code .token.class-name {
      color: #795e26;
  }

  pre>code .token.regex,
  pre>code .token.important,
  pre>code .token.variable {
      color: #e90;
  }

  /* Blockquote styles */
  blockquote {
      border-left: 4px solid var(--secondary-color);
      margin-bottom: 1.1rem;
      font-size: 0.8rem;
      line-height: 1.5;
      margin-left: 0;
      color: var(--dark-gray);
      font-style: italic;
      font-weight: 700;
  }

  /* List styles */
  ul,
  ol {
      font-size: var(--p-size);
      margin-bottom: var(--element-margin);
  }

  li {
      margin-bottom: 0.4rem;
  }

  /* Footer and header customization */
  footer,
  header {
      font-size: 0.8em;
      color: var(--primary-color);
      opacity: 0.8;
  }

  /* Background image adjustments */
  img[bg] {
      opacity: 0.2;
  }

  /* Link styling */
  a {
      color: var(--accent-color);
      text-decoration: none;
  }

  a:hover {
      text-decoration: underline;
  }

  /* Custom classes for special elements */
  .highlight {
      background-color: rgba(234, 89, 54, 0.1);
      padding: 0.2rem 0.4rem;
      border-radius: 3px;
      font-weight: 500;
  }

  .callout {
      border-left: 4px solid var(--secondary-color);
      background-color: var(--light-gray);
      padding: 1rem;
      margin: 1rem 0;
  }

  /* Center the lead/title slide */
  .lead {
      justify-content: center;
      text-align: center;
  }

  /* References slide - smaller text */
  .references {
      font-size: 0.55em !important;
      padding-bottom: 0.5rem;
  }

  .references h2 {
      font-size: 1.3em !important;
      margin-bottom: 0.3rem;
      margin-top: 0;
  }

  .references p,
  .references li,
  .references a {
      font-size: 0.55em !important;
      line-height: 1.25;
      margin-bottom: 0.1rem;
  }

  .references strong {
      font-size: 0.6em !important;
      display: block;
      margin-top: 0.5rem;
      margin-bottom: 0.15rem;
  }

  .references ol {
      margin-top: 0.2rem;
      padding-left: 1.2rem;
  }

  .references li {
      margin-bottom: 0.1rem;
  }

  .references a {
      word-break: break-all;
  }

  /* References slide - full page layout */
  section.references {
      display: block;
      padding-top: 1rem;
      overflow: hidden;
  }
---
