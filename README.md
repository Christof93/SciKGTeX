# ORKG4LaTeX
ORKG4LaTeX makes it possible to annotate specific **research contributions** directly in the LaTeX source code. The idea of extracting research contributions from scholarly publications is derived from the Open Research Knowledge Graph (ORKG).

With ORKG4LaTeX, authors of scientific publications can enrich their documents with structured, reduced and machine-readable information which represents the key points of the content they want to communicate.  The production of this additional information improves electronic archiving of the information for the future and boosts discoverability in search engines and recommendation engines.
The ORKG contribution data is embedded into the PDF's XMP metadata where they can be retrieved by anyone who obtains the PDF document and persist for the lifetime of the document.
Additionally the contributions can easily be added to the actual ORKG knowledge graph by just uploading the annotated document to the ORKG web portal.

##### Table of Contents
- [Installation](#installation)
-  [Using the LaTeX Package](#using-the-latex-package)
    * [Minimal Example](#minimal-example)
    * [Optional Properties](#optional-properties)
    * [Defining Custom Properties](#defining-custom-properties)
    * [Contribution Numbering](#contribution-numbering)
    * [Invisible Markup](#invisible-markup)

## Installation
1. Clone this repository
2. Move the `orkg4latex.lua` and `orkg4latex.sty` files to your latex project
3. use `\usepackage{orkg4latex}` in your document preamble to use the package

It is necessary to compile your LaTeX source with LuaLaTeX for the package to work. This is typically straightforward with most modern LaTeX environments.
In Overleaf it can be configured like this for example:

<img src="documentation/pictures/lualatex_overleaf.png?raw=true" alt="setting lualatex on overleaf" width="500"/>

  
## Using the LaTeX Package
### Minimal Example
To create a contribution we have to assign one the 5 standard properties to sentences or statements in the text:

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

Now we can mark passages in the text with these commands as illustrated by this example of a summarized research article.
Wald, Ellen R., David Nash, and Jens Eickhoff. “Effectiveness of Amoxicillin/Clavulanate Potassium in the Treatment of Acute Bacterial Sinusitis in Children.” Pediatrics, vol. 124, no. 1, 2009, pp. 9-15.:

```latex
\documentclass{article}
\usepackage{orkg4latex}

\title{Effectiveness of Amoxicillin/Clavulanate Potassium in the Treatment of Acute Bacterial Sinusitis in Children.}
\author{Ellen R. Wald \and David Nash \and Jens Eickhoff}

\begin{document}
\maketitle

\begin{abstract}
\ORKGbackground{The role of antibiotic therapy in managing acute bacterial sinusitis (ABS) in children is controversial}.
The purpose of this study was to determine the \ORKGresearchproblem{effectiveness of high-dose amoxicillin/potassium clavulanate in the treatment of children diagnosed with ABS}.

This was a \ORKGmethod{randomized, double-blind, placebo-controlled study}.
Children 1 to 10 years of age with a clinical presentation compatible with ABS were eligible for participation.
\ORKGmethod{Patients were stratified according to age (<6 or ≥6 years) and clinical severity and randomly assigned to receive either amoxicillin (90 mg/kg) with potassium clavulanate (6.4 mg/kg) or placebo}.
A symptom survey was performed on days 0, 1, 2, 3, 5, 7, 10, 20, and 30.
Patients were examined on day 14.
Children’s conditions were rated as cured, improved, or failed according to scoring rules.

Two thousand one hundred thirty-five children with respiratory complaints were screened for enrollment; 139 (6.5\%) had ABS.
Fifty-eight patients were enrolled, and 56 were randomly assigned. The mean age was 6630 months.
Fifty (89\%) patients presented with persistent symptoms, and 6 (11\%) presented with nonpersistent symptoms.
In 24 (43\%) children, the illness was classified as mild, whereas in the remaining 32 (57\%) children it was severe.
Of the 28 children who received the antibiotic, 14 (50\%) were cured, 4 (14\%) were improved, 4(14\%) experienced treatment failure, and 6 (21\%) withdrew.
Of the 28children who received placebo, 4 (14\%) were cured, 5 (18\%) improved, and 19 (68\%) experienced treatment failure.
\ORKGresult{Children receiving the antibiotic were more likely to be cured (50\% vs 14\%) and less likely to have treatment failure (14\% vs 68\%) than children receiving the placebo}.
ABS is a common complication of viral upper respiratory infections. \ORKGconclusion{Amoxicillin/potassium clavulanate results in significantly more cures and fewer failures than placebo}, according to parental report of time to resolution.”
\end{abstract}
\end{document}
```

The produced document will then look like this:

<img src="documentation/pictures/rendered_example.png?raw=true" alt="how it looks rendered" width="800"/>

As can be seen in the rendered pdf the marked properties can not be distinguished from the other sentences in the text. They can be inspected however in the file `xmp_metdata.xml` which is directly embedded into the pdf metadata. For our example the content of the metadata will look as such:

```xml
<x:xmpmeta xmlns:x="adobe:ns:meta/">
<rdf:RDF 
  xmlns:orkg="http://orkg.org/core#"
  xmlns:orkg_property="http://orkg.org/property"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="R1234565">
    <rdf:type rdf:resource="http://orkg.org/core#Paper"/>
    <orkg:hasResearchContribution>
      <orkg:ResearchContribution rdf:about="contribution_ORKG_default">
          <orkg_property:ORKGbackground>The role of antibiotic therapy in managing acute bacterial sinusitis (ABS) in children is controversial</orkg_property:ORKGbackground>
          <orkg_property:ORKGresearchproblem>effectiveness of high-dose amoxicillin/potassium clavulanate in the treatment of children diagnosed with ABS</orkg_property:ORKGresearchproblem>
          <orkg_property:ORKGmethod>randomized, double-blind, placebo-controlled study</orkg_property:ORKGmethod>
          <orkg_property:ORKGmethod>Patients were stratified according to age (&lt;6 or ≥6 years) and clinical severity and randomly assigned to receive either amoxicillin (90 mg/kg) with potassium clavulanate (6.4 mg/kg) or placebo</orkg_property:ORKGmethod>
          <orkg_property:ORKGresult>Children receiving the antibiotic were more likely to be cured (50vs 14and less likely to have treatment failure (14vs 68than children receiving the placebo</orkg_property:ORKGresult>
      </orkg:ResearchContribution>
    </orkg:hasResearchContribution>
  </rdf:Description>
</rdf:RDF>
</x:xmpmeta>
```
<a name="optional-properties"/>

### Optional Properties

Additional to the 5 standard ones, there are a big number of more specific properties which are optional and are generally used in a specific domain of science. For example properties of _p-value_ or _accuracy_ are useful for studies that include statistical examinations and can be used with `\ORKGpvalue{}` and `ORKGaccuracy{}`. A comprehensive list of ORKG properties can be found [here](https://www.orkg.org/orkg/).  

### Defining Custom Properties
If a property is not already predefined, it is possible to declare new properties in your document preamble with `\ORKGaddproperty`. These properties can then be used to describe a contribution with a command just like the predefined commands. To avoid clashes with already existing commands, you should use the prefix _ORKG_ in the property name. 

For example a minimal LaTeX file could look like this:

```latex
\documentclass{article}
\usepackage{orkg4latex}
\ORKGaddproperty{ORKGprecision}
\begin{document}
...
```

### Contribution Numbering
A scientific paper typically has a small number of contributions. If we want to distinguish more than one contribution we can number the contributions as an argument of the marked properties. An annotation of `ORKGresearchproblem[1]{..}` and `ORKGresearchproblem[2]{..}` adds two contributions with the respective research problems. These two contributions can have their own background, methods and results which must be numbered accordingly.

If two problems have the same background, or methods, we can assign the same property to two contributions using a comma between the arguments:  `ORKGmethod[1,2]{..}`.

### Invisible Markup

