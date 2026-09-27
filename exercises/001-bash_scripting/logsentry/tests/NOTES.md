# Notes ShellCheck — Anti-patterns fréquents

* **SC2086** (*Double quote to prevent globbing and word splitting*) : Toujours entourer les variables de guillemets `"$var"` pour éviter que le Shell ne découpe la valeur sur les espaces ou n'interprète les caractères jokers (`*`, `?`).
* **SC2046** (*Quote this to prevent word splitting*) : Entourer les substitutions de commandes `"$(command)"` de guillemets pour empêcher le Shell d'éclater le résultat en plusieurs arguments distincts.
* **SC2181** (*Check exit code directly*) : Éviter de tester `$?` après coup (`cmd; if [ $? -eq 0 ]`). Tester directement la commande dans la structure de contrôle (`if cmd; then`).
* **SC2002** (*Useless use of cat*) : Utilisation inutile de `cat` dans un pipeline (`cat file | grep pattern`). Préférer passer le fichier en argument (`grep pattern file`) ou utiliser une redirection (`< file`).
* **SC2164** (*Use cd ... || exit*) : Toujours sécuriser un changement de répertoire (`cd dir || exit 1`) pour éviter que le script ne continue à s'exécuter dans le mauvais dossier en cas d'échec.
