# Module 1 (agentic development, AIB): changes for the joint workshop day

Copied from Keren's repository: the two student guides. The AIB package and zpm installer are loaded into the
workshop image (namespace AI with interoperability; IPM 0.10.10 in USER and AI; agentic-integration-builder 0.5.0
in AI only, as Keren confirmed - so /ai/frontend and /ai/backend serve AI). Edits inside the guides:

- `IRIS_Agentic_Development_Workshop_v4_he.docx`: `בספרייה אליה הורדתם את ה-iris container קיים כבר קובץ בשם docker-compose.yml. פתחו command line בספריה אליה הורדתם את ה-docker והפעילו את IRIS:` -> `בתיקיית מאגר הסדנה (ai-workshop-day) קיים כבר קובץ בשם compose.yaml. פתחו command line בתיקייה זו והפעילו את IRIS:` (1x) - the joint repo's compose.yaml (one container for the day)
- `IRIS_Agentic_Development_Workshop_v4_he.docx`: `docker-compose up -d` -> `docker compose up -d` (2x) - Docker Compose v2 syntax, as in the joint README
- `IRIS_Agentic_Development_Workshop_v4_he.docx`: `container = "iris"` -> `container = "aiworkshop-iris"` (1x) - the joint container is called aiworkshop-iris
- `IRIS_Agentic_Development_Workshop_v4_he.docx`: Part 1 step 1 (C:\Tools, PATH, downloading iris-agentic-dev.exe, `--version`) moved to the repository's main README (prework before the day); in its place: "שלב זה הוא חלק מההכנה לפני יום הסדנה: ההוראות (תיקיית C:\Tools, ה-PATH והורדת iris-agentic-dev.exe) נמצאות ב-README הראשי של מאגר הסדנה, בשלב 2. ודאו ש-iris-agentic-dev --version מציג מספר גרסה."
- `AIB_Workshop_he_v2.docx`: `http://localhost:52773/csp/sys/UtilHome.csp` -> `http://localhost:42773/csp/sys/UtilHome.csp` (2x) - the joint container's web port is 42773
- `AIB_Workshop_he_v2.docx`: `docker exec -it iris bash` -> `docker exec -it aiworkshop-iris bash` (1x) - the joint container is called aiworkshop-iris
- `AIB_Workshop_he_v2.docx`: `iris session iris` -> `iris session IRIS` (1x) - the instance is called IRIS
- `AIB_Workshop_he_v2.docx`: added after "חלק זה מבוצע על ידי מנהל Cloud Portal לפני הסדנה. אם AIB כבר מופעל בסביבתכם, דלגו לחלק 2.": "בסביבת הסדנה המשותפת השלבים של הורדת הקבצים, יצירת ה-namespace AI, העתקת הקבצים וטעינת zpm ו-AIB כבר בוצעו בתוך הקונטיינר (ב-namespace AI). התחילו מהשלב "לאחר ההתקנה": פתחו את ממשק ה-AIB בכתובת http://localhost:42773/iris/ai/frontend/index.html והמשיכו משם (Settings, Models, Namespaces)." - the admin setup is done in the image

Left as they were: the `set IRIS_PORT=52773` example (option B, a remote server), and the admin steps of the AIB guide (kept for reference, with the note above).
Open for Keren: after students create and start their own production (WorkshopDemo) in namespace AI, AIB's own production AI.Harness.Production stops (one production per namespace) - does AIB keep working?
