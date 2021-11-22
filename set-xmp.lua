local XMP = {}
XMP.lines = {}

local xmp_top = [[<?xpacket begin="" id="b0e1b454-39bf-11ec-8d3d-0242ac130003"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:orkg="http://orkg.org/core/"
  xmlns:po="http://purl.org/spar/po/"
  xmlns:c4o="http://purl.org/spar/c4o"
  xmlns:deo="http://purl.org/spar/deo">
  <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:format>application/pdf</dc:format>
  </rdf:Description>]]

local xmp_bottom = [[</rdf:RDF>
</x:xmpmeta>
<?xpacket end="r"?>]]

function XMP.add_line(...) 
    table.insert(XMP.lines, string.format(...))
end

function XMP.add_paper_node(paper_iri) 
    XMP.paper = {}
    XMP.paper.contributions = {}
    XMP.paper.id = paper_iri
end

function XMP.add_contribution(contribution_iri)
    local contribution = {}
    contribution.annotations = {}
    contribution.id = contribution_iri
    table.insert(XMP.paper.contributions, contribution)
end

function XMP.add_annotation(annotation_type, content, annotation_iri)
    local annotation = {}
    annotation.type = annotation_type
    annotation.content = content
    annotation.id = annotation_iri
    table.insert(XMP.paper.contributions[1].annotations, annotation)
end

function escape_xml_content(s)
    s = string.gsub(s, '&', '&amp;')
    return string.gsub(s, '<', '&lt;')
end

function XMP.generate_output()
    output_string = ""
    XMP.add_line(xmp_top)
    --print(debug.traceback())

    if XMP.paper then
        XMP.add_line('  <rdf:Description rdf:about="%s">', XMP.paper.id)
        XMP.add_line('    <rdf:type rdf:resource="http://orkg.org/core#Paper"/>')
        for i, contribution in ipairs(XMP.paper.contributions) do
            XMP.add_line('    <orkg:hasResearchContribution>')
            XMP.add_line('      <orkg:ResearchContribution rdf:about="%s">', contribution.id)
            for j, annotation in ipairs(contribution.annotations) do
                XMP.add_line('        <po:contains>')
                XMP.add_line('          <orkg:Annotation rdf:about="%s">', annotation.id)
                XMP.add_line('            <rdf:type rdf:resource="http://purl.org/spar/deo#%s"/>', annotation.type)
                XMP.add_line('            <c4o:hasContent>%s</c4o:hasContent>', escape_xml_content(annotation.content))
                XMP.add_line('          </orkg:Annotation>')
                XMP.add_line('        </po:contains>')
            end
            XMP.add_line('      </orkg:ResearchContribution>')
            XMP.add_line('    </orkg:hasResearchContribution>')
        end
        XMP.add_line('  </rdf:Description>')
    end
    XMP.add_line(xmp_bottom)
    return table.concat(XMP.lines, '\n')

end

function XMP.make_metadata_object()
    local xmp_string = XMP.generate_output()
    local new_pdf = pdf.obj {
        type = 'stream',
        attr = '/Type/Metadata /Subtype/XML',
        immediate = true,
        compresslevel = 0,
        string = xmp_string,
    }
    XMP.lines = nil
    return new_pdf
end

-- 1 Writing metadata packets
callback.register('finish_pdffile', function()
    if XMP.paper then
        local metadata_obj = XMP.make_metadata_object()
        local catalog = pdf.getcatalog() or ''
        pdf.setcatalog(catalog..string.format('/Metadata %s 0 R', metadata_obj))
    end
end)

return XMP
