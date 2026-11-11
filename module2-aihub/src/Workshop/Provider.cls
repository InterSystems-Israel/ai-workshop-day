Include (%AI, %occStatus)

/// Resolves an %AI.Provider from the process environment, so every workshop
/// agent is provider-configurable from one variable (AI_PROVIDER) without
/// editing any class.
///
/// Reads AI_PROVIDER, AI_MODEL and the matching <PROVIDER>_API_KEY, which
/// docker compose injects from .env. Environment variables are read when the
/// IRIS process starts, so after editing .env:
///     docker compose up -d --force-recreate iris
///
/// CLASSROOM SHORTCUT: a key in the process environment is convenient but it
/// is visible to anything running in the instance. The production route is the
/// Config Store plus a Wallet secret:// reference, which Module D builds:
///     Parameter PROVIDERCONFIG = "@{config:AI.LLM.ProductionLLM}";
Class Workshop.Provider Extends %RegisteredObject
{

/// Default model per provider, used when AI_MODEL is not set.
ClassMethod DefaultModel(provider As %String) As %String
{
    Return $Case(provider,
        "anthropic":   "claude-sonnet-5-5",
        "openai":      "gpt-4o-mini",
        "gemini":      "gemini-2.0-flash",
        "deepseek":    "deepseek-chat",
        "ollama":      "qwen3:8b",
                     : "")
}

/// Read a key from the process environment, falling back to ^||ENV.
///
/// IMPORTANT, and not what the EAP material implies: ^||ENV is NOT a
/// framework feature. Nothing in %AI.* reads it — it is a convention
/// implemented by Sample.AI.Utils.GetEnvKey(), which we deliberately
/// replicate here so the "no restart" tip actually works in this workshop.
///
/// Second caveat: ^|| is a PROCESS-PRIVATE global, so a key set this way
/// exists only for the process that set it. Perfect for a demo in one
/// terminal; it will NOT be seen by an MCP request or a business host, which
/// run in other processes. Those need the real environment variable or the
/// Config Store.
ClassMethod GetEnvKey(varName As %String) As %String [ Private ]
{
    Set val = $ZStrip($System.Util.GetEnviron(varName), "<>W")
    If val '= "" Return val
    Return $Get(^||ENV(varName))
}

/// Environment variable holding the key for a given provider.
ClassMethod KeyVariable(provider As %String) As %String
{
    Return $Case(provider,
        "anthropic":   "ANTHROPIC_API_KEY",
        "openai":      "OPENAI_API_KEY",
        "gemini":      "GEMINI_API_KEY",
        "deepseek":    "DEEPSEEK_API_KEY",
        "azureopenai": "AZURE_OPENAI_API_KEY",
                     : $ZConvert(provider, "U") _ "_API_KEY")
}

/// Build a configured provider. Returns the model to use in the output
/// argument, because the provider object does not carry one.
ClassMethod Get(Output model As %String, Output sc As %Status) As %AI.Provider
{
    Set sc = $$$OK, model = ""

    Set which = $ZConvert($ZStrip($System.Util.GetEnviron("AI_PROVIDER"), "<>W"), "L")
    If which = "" Set which = "anthropic"

    Set model = $ZStrip($System.Util.GetEnviron("AI_MODEL"), "<>W")
    If model = "" Set model = ..DefaultModel(which)
    If model = "" {
        Set sc = $$$ERROR($$$GeneralError, "AI_MODEL is not set and there is no default for provider '" _ which _ "'")
        Return $$$NULLOREF
    }

    // Ollama is reached through the "openai" provider via its
    // OpenAI-compatible API — there is no "ollama" provider name in
    // %AI.Provider. (On the Python/LangChain path there is, because that
    // forwards model_provider straight to LangChain.)
    If which = "ollama" {
        Set base = $System.Util.GetEnviron("OLLAMA_BASE_URL")
        If base = "" Set base = "http://host.docker.internal:11434/v1"
        Return ##class(%AI.Provider).Create("openai", {"api_key": "ollama", "base_url": (base)})
    }

    Set keyvar = ..KeyVariable(which)
    Set key = ..GetEnvKey(keyvar)
    If key = "" {
        Set msg = keyvar _ " is not set. Put it in .env then 'docker compose up -d --force-recreate iris', or for this terminal session only: Set ^||ENV("""_keyvar_""")=""sk-..."""
        Set sc = $$$ERROR($$$GeneralError, msg)
        Return $$$NULLOREF
    }

    Set settings = {"api_key": (key)}
    If which = "azureopenai" {
        Set settings."base_url" = $System.Util.GetEnviron("AZURE_OPENAI_ENDPOINT")
        Set settings."api_version" = $System.Util.GetEnviron("AZURE_OPENAI_API_VERSION")
    }

    Return ##class(%AI.Provider).Create(which, settings)
}

/// Print what the instance can actually see. First thing to run when an
/// agent will not talk.
ClassMethod Report()
{
    Set which = $ZConvert($ZStrip($System.Util.GetEnviron("AI_PROVIDER"), "<>W"), "L")
    If which = "" Set which = "anthropic (defaulted)"
    Write "AI_PROVIDER : ", which, !
    Write "AI_MODEL    : ", $System.Util.GetEnviron("AI_MODEL"), !
    Set p = $ZConvert($ZStrip($System.Util.GetEnviron("AI_PROVIDER"), "<>W"), "L")
    If p = "" Set p = "anthropic"
    Set keyvar = ..KeyVariable(p)
    Set key = ..GetEnvKey(keyvar)
    // Never print the key itself. Length plus last 4 chars is enough to tell
    // "wrong key" from "no key" without leaking it into a transcript.
    Write keyvar, " : ", $Select(key = "": "** NOT SET **", 1: "set, " _ $Length(key) _ " chars, ends " _ $Extract(key, *-3, *)), !
    Write "  (source    : ", $Select($System.Util.GetEnviron(keyvar) '= "": "process environment",
                                     $Get(^||ENV(keyvar)) '= "": "^||ENV, this process only",
                                     1: "none"), ")", !
}

}
