/// Exercise 3 - Does the index make vector search faster? (slides 15-17)
/// Two tables with the same 100,000 vectors: Workshop.BenchExact (no index) and Workshop.BenchHNSW (an HNSW index).
/// In the IRIS terminal (Workshop Guide, Exercise 3):
/// TODO 2: the timing in Search().
/// <pre>set q = ##class(Workshop.Exercise.Ex3).QueryVector(10)                          // a vector to search for
/// write ##class(Workshop.Exercise.Ex3).Search("Workshop.BenchExact", q)            // ms per search, no index
/// write ##class(Workshop.Exercise.Ex3).Search("Workshop.BenchHNSW", q)             // ms per search, with the index
/// write ##class(Workshop.Exercise.Ex3).Same(q)                                     // how many of the 10 results agree</pre>
Class Workshop.Exercise.Ex3 Extends %RegisteredObject
{

/// A vector to search for: query vector n (1-59) from Workshop.BenchQueries - 384 numbers, made the same way as the
/// table's vectors (they are synthetic, meaningless numbers, only for measuring).
ClassMethod QueryVector(n As %Integer = 10) As %Vector
{
    &sql(SELECT vec INTO :vector FROM Workshop.BenchQueries WHERE q_no = :n)
    return vector
}

/// The query: the 10 nearest vectors to q (dot product, best first) - the same SQL for both tables.
ClassMethod Query(table As %String) As %SQL.Statement
{
    set stmt = ##class(%SQL.Statement).%New()
    set stmt.%SelectMode = 0       // logical mode: q is passed as an IRIS vector
    $$$ThrowOnError(stmt.%Prepare("SELECT TOP 10 vec_id FROM "_table_" ORDER BY VECTOR_DOT_PRODUCT(vec, TO_VECTOR(?, FLOAT, 384)) DESC"))
    return stmt
}

/// Run the search 10 times and return the average time in milliseconds - only the search itself is timed
/// (q is already a vector). Averaging over 10 runs means one slow run does not decide.
ClassMethod Search(table As %String, q As %Vector) As %Double
{
    set stmt = ..Query(table)
    // TODO 2: Paste these 6 lines (the timing): set t0 = $zhorolog / for i = 1:1:10 { set rs = stmt.%Execute(q)  while rs.%Next() { } } / return ($zhorolog - t0) * 1000 / 10 - see the Workshop Guide, Exercise 3 step 2
    do ##class(Workshop.Util).Todo(2, "Paste these 6 lines (the timing): set t0 = $zhorolog / for i = 1:1:10 { set rs = stmt.%Execute(q)  while rs.%Next() { } } / return ($zhorolog - t0) * 1000 / 10 - see the Workshop Guide, Exercise 3 step 2")
}

/// The 10 vec_ids a table returns for q, best first.
ClassMethod TopIds(table As %String, q As %Vector) As %List
{
    set ids = "", rs = ..Query(table).%Execute(q)
    while rs.%Next() {
        set ids = ids_$listbuild(rs.%Get("vec_id"))
    }
    return ids
}

/// The index searches a graph of neighbours instead of every row, so it can miss one: how many of the exact
/// top 10 did the index find too?
ClassMethod Same(q As %Vector) As %String
{
    set exact = ..TopIds("Workshop.BenchExact", q), hnsw = ..TopIds("Workshop.BenchHNSW", q), same = 0
    for i = 1:1:$listlength(exact) {
        set same = same + ($listfind(hnsw, $list(exact, i)) > 0)
    }
    return same_" of "_$listlength(exact)_" the same"
}

}
