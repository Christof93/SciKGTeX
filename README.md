# ORKG4LaTeX
ORKG4LaTeX makes it possible to annotate specific **research contributions** directly in the LaTeX source code. The idea of extracting research contributions from scholarly publications is derived from the Open Research Knowledge Graph (ORKG).

With ORKG4Latex, authors of scientific publications can enrich their documents with machine-readable, structured information which in turn helps to improve visibility in search engines and recommendation engines.
The ORKG information triples are embedded into the PDF's XMP metadata where they can be retrieved by anyone who obtains the PDF document and persist for the lifetime of the document.
Additionally the contributions can easily be added to the knowledge graph by just uploading the annotated document to the ORKG web portal.

## Installation
1. Clone this repository
2. Move the `orkg4latex.lua` and `orkg4latex.sty` files to your latex project
3. use `\usepackage{orkg4latex}` in your document preamble to use the package

It is necessary to compile your LaTeX source with LuaLaTeX for the package to work. This is typically straightforward with most modern LaTeX environments.
In Overleaf it can be configured like this for example:

<img src="documentation/pictures/lualatex_overleaf.png?raw=true" alt="setting lualatex on overleaf" width="500"/>

## Using the LaTeX package
Each specified contribution has 5 standard properties which should be assigned to sentences in the text:
* _research problem_ 
* _background_
* _method_
* _result_
* _conclusion_

For each of these properties there exists a corresponding LaTeX command:
* `\ORKGresearchproblem{..}`
* `\ORKGbackground{..}`
* `\ORKGmethod{..}`
* `\ORKGresult{..}`
* `\ORKGconclusion{..}`

Additional to that, there are a big number of more specific properties like _p-value_ or _accuracy_ for contributions which concern statistical examinations.
If a property is not already predefined, it is possible to declare new properties in your document preamble with `\ORKGaddproperty`. These properties can then be used to describe a contribution with a command just like the predefined commands.

For example a minimal LaTeX file could look like this:

```
\documentclass{article}
\usepackage{orkg4latex}
\title{My Newest Research}
\begin{document}

\section{Introduction}
\ORKGbackground{This is the background of our research.}
\ORKGresearchproblem{This is the problem statement of our research.}
\ORKGmethod{These are the methods of our research.}
\ORKGresult{These are the results of our research.}

\end{document}
```

A scientific paper typically has a small number of contributions.
Let's look at an example paper:

