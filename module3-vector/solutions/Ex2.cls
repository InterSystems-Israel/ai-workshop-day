/// Exercise 2 - From PDF files to searchable chunks (slides 9-14, 22).
/// documents -> sections (our chunks) -> a table that keeps a vector for every text -> search with SQL.
/// The documents are four fictional handbooks (data/pdfs in the project, /workshop/data/pdfs inside IRIS).
/// <p>In the IRIS terminal: <code>write ##class(Workshop.Exercise.Ex2).IngestAll()</code> - after TODO 1 in StoreChunk().</p>
Class Workshop.Exercise.Ex2 Extends %RegisteredObject
{

Parameter PDFDIR = "/workshop/data/pdfs";

/// The table. The column "embedding" has the type EMBEDDING('workshop-minilm', 'content'): IRIS computes the vector
/// of "content" itself - with the model you registered in Exercise 1 - whenever a row is inserted or updated.
ClassMethod CreateTable()
{
    &sql(CREATE TABLE Workshop.SupportChunks (
            chunk_id VARCHAR(40),
            title VARCHAR(200),
            source VARCHAR(200),
            content VARCHAR(4000),
            embedding EMBEDDING('workshop-minilm', 'content')))
}

/// Step 1 - read all text from a PDF. ObjectScript has no PDF reader, so this is two lines of Python (pypdf).
ClassMethod ReadPdf(path As %String) As %String [ Language = python ]
{
    from pypdf import PdfReader
    return "\n".join(page.extract_text() for page in PdfReader(path).pages)
}

/// Step 2 - CHUNKING: cut a handbook into its numbered sections. A section starts with a heading line such as
/// "2. Backup schedule and retention"; each section becomes one chunk, with an ID like "backup-restore §2".
ClassMethod SplitSections(text As %String, handbook As %String) As %DynamicArray
{
    set sections = [], current = ""
    for i = 1:1:$length(text, $char(10)) {
        set line = $zstrip($piece(text, $char(10), i), "<>W")
        if $match(line, "\d{1,2}\. [A-Z].*[^.]") {
            // a heading line: a new section starts
            set current = {"id": (handbook_" §"_$piece(line, ".", 1)), "title": ($zstrip($piece(line, ".", 2, *), "<>W")), "text": ""}
            do sections.%Push(current)
        } elseif $isobject(current) {
            // a text line: add it to the current section
            set current.text = $zstrip(current.text_" "_line, "<>W")
        }
    }
    return sections
}

/// Step 3 - store one chunk: a plain INSERT of the text. IRIS fills the embedding column by itself.
ClassMethod StoreChunk(id As %String, title As %String, source As %String, content As %String)
{
    &sql(INSERT INTO Workshop.SupportChunks (chunk_id, title, source, content) VALUES (:id, :title, :source, :content))
    if SQLCODE < 0 { throw ##class(%Exception.SQL).CreateFromSQLCODE(SQLCODE, %msg) }
}

/// Steps 1-3 for one PDF. Returns the number of chunks stored. show = 0: no list of stored chunks.
ClassMethod IngestPdf(path As %String, show As %Boolean = 1) As %Integer
{
    set source = ##class(%File).GetFilename(path)
    set handbook = $piece($piece($piece(source, "-handbook.pdf"), "-guide.pdf"), "-runbook.pdf")   // "backup-restore"
    &sql(DELETE FROM Workshop.SupportChunks WHERE source = :source)      // re-running never creates duplicates
    set sections = ..SplitSections(..ReadPdf(path), handbook)
    set iter = sections.%GetIterator()
    while iter.%GetNext(.i, .section) {
        do ..StoreChunk(section.id, section.title, source, section.text)
        write:show "   stored ", section.id, "  ", section.title, !
    }
    return sections.%Size()
}

/// All four handbooks. Returns the number of chunks stored. show = 0: no list of stored chunks.
ClassMethod IngestAll(show As %Boolean = 1) As %Integer
{
    do ##class(Workshop.Util).Checkpoint(2)         // Exercise 1 done? (model downloaded and registered)
    if '##class(Workshop.Util).TableExists("SupportChunks") {
        do ..CreateTable()
    }
    set n = 0
    for file = "accounts-handbook.pdf", "data-import-handbook.pdf", "vector-search-guide.pdf", "backup-restore-handbook.pdf" {
        set n = n + ..IngestPdf(..#PDFDIR_"/"_file, show)
    }
    return n
}

}
