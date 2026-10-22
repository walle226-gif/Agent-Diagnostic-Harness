The README stays true

Now: The README describes commands by hand and can drift from the program.

Should: A command reference is generated from every command's --help and written into the README between two marker lines. A test fails if the README differs from the generated text.

Part 1: The generator, as "ledger docs --write README.md".
Done when: A test runs the command twice and finds the README unchanged the second time.

Part 2: The test that compares the README with the generated text.
Done when: The test passes now, and fails if a command's help text is changed without updating the README.

Every part's new test must fail on today's code and pass after the part.
Rules: Work only inside this project folder. Do not add, remove or update packages. Keep every existing test green and the full test run under 2 minutes. Throwaway scripts go in _scratch/, which git ignores; do not commit them.
