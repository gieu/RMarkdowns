"""Run with: python3 -m unittest discover -s deploy/tests -v."""

import csv
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest


DEPLOY = Path(__file__).resolve().parents[1]


class HelpersTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="shiny helpers ")
        self.root = Path(self.tmp.name)
        self.source = self.root / "source"
        (self.source / "markdowns").mkdir(parents=True)
        (self.source / "datos").mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def notebook(self, folder, body):
        path = self.source / "markdowns" / folder / "tutorial.Rmd"
        path.parent.mkdir(parents=True)
        path.write_text('---\ntitle: "Prueba"\noutput: html_document\n---\n\n' + body)
        return path

    def render(self, destination):
        return subprocess.run(
            ["Rscript", "--vanilla", str(DEPLOY / "render-notebooks.R"),
             str(self.source), str(destination)],
            capture_output=True, text=True, timeout=60,
        )

    @staticmethod
    def results(destination):
        with (destination / "resultados.tsv").open() as handle:
            return list(csv.DictReader(handle, delimiter="\t"))

    def test_fresh_sessions_quoted_paths_and_unchanged_sources(self):
        first = self.notebook("uno & dos", "```{r}\nleak <- 99\n1 + 1\n```\n")
        second = self.notebook("tres", "```{r}\nstopifnot(!exists('leak'))\n2 + 2\n```\n")
        before = [hashlib.sha256(p.read_bytes()).hexdigest() for p in (first, second)]
        out = self.root / "release"
        result = self.render(out)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([r["estado"] for r in self.results(out)], ["0", "0"])
        self.assertTrue((out / "site/markdowns/uno & dos/tutorial.html").is_file())
        self.assertTrue((out / "logs").is_dir())
        self.assertFalse((out / "site/logs").exists())
        self.assertEqual(
            before, [hashlib.sha256(p.read_bytes()).hexdigest() for p in (first, second)]
        )
        self.assertFalse(first.with_suffix(".html").exists())

    def test_site_is_readable_even_if_source_directories_are_private(self):
        path = self.notebook("privado", "Contenido.\n")
        path.parent.chmod(0o700)
        path.chmod(0o600)
        out = self.root / "release"
        result = self.render(out)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for item in (out / "site/markdowns/privado").rglob("*"):
            self.assertTrue(item.stat().st_mode & 0o004, f"{item} no es legible")
        self.assertTrue(
            (out / "site/markdowns/privado").stat().st_mode & 0o001,
            "La carpeta debe poder atravesarse",
        )

    def test_missing_license_blocks_release_then_passes_when_provided(self):
        path = self.notebook("licencia", '```{r}\nhtmltools::includeHTML("license.html")\n```\n')
        self.notebook("otro", "Contenido válido.\n")
        failed = self.root / "failed"
        result = self.render(failed)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.results(failed)), 2)
        self.assertIn("1", [r["estado"] for r in self.results(failed)])
        self.assertTrue(list((failed / "logs").glob("*.log")))
        (path.parent / "license.html").write_text("<p>Licencia de prueba.</p>")
        result = self.render(self.root / "fixed")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_existing_and_nested_destinations_are_rejected(self):
        self.notebook("uno", "Contenido.\n")
        existing = self.root / "existing"
        existing.mkdir()
        marker = existing / "user-work"
        marker.write_text("No modificar")
        self.assertNotEqual(self.render(existing).returncode, 0)
        self.assertEqual(marker.read_text(), "No modificar")
        self.assertNotEqual(self.render(self.source / "nested").returncode, 0)
        self.assertFalse((self.source / "nested").exists())

    def executable(self, directory, name, body):
        path = directory / name
        path.write_text("#!/usr/bin/env python3\n" + body)
        path.chmod(0o755)

    def test_failed_build_never_runs_or_prepares_activation(self):
        server = self.root / "server"
        server.mkdir()
        for name in ("install_shiny_server.sh", "install_pandoc.sh", "install_s6init.sh"):
            (server / name).write_text("#!/bin/sh\nexit 0\n")
        shutil.copytree(DEPLOY, self.source / "deploy")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        log = self.root / "commands"
        self.executable(bin_dir, "docker", """
import json, os, sys
with open(os.environ["MOCK_LOG"], "a") as f:
    f.write(json.dumps(sys.argv[1:]) + "\\n")
sys.exit(17 if sys.argv[1] == "build" else 0)
""")
        env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
                   MOCK_LOG=str(log))
        release = self.root / "candidate"
        result = subprocess.run(
            ["bash", str(DEPLOY / "prepare-release.sh"), str(server),
             str(self.source), str(release), "test:candidate"],
            env=env, capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 17)
        commands = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual([c[0] for c in commands], ["info", "build"])
        self.assertFalse((release / "compose.release.json").exists())

    def test_webhook_defaults_to_preparation_and_rolls_back_failed_activation(self):
        # Put source- in the server path to exercise release-path construction.
        server = self.root / "source-server"
        (server / "mountpoints/apps").mkdir(parents=True)
        (server / "docker-compose.yml").write_text("version: '3.0'\nservices: {}\n")
        old_site = server / "old site"
        old_site.mkdir()
        marker = old_site / "user-work"
        marker.write_text("Sin cambios")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        archive = self.root / "source.tar"
        helper = b'#!/bin/bash\nset -eu\nmkdir "$3"\nprintf "{}" > "$3/compose.release.json"\n'
        with tarfile.open(archive, "w") as handle:
            entry = tarfile.TarInfo("deploy/prepare-release.sh")
            entry.size = len(helper)
            handle.addfile(entry, io.BytesIO(helper))
        log = self.root / "commands"
        self.executable(bin_dir, "git", """
import os, sys
args = sys.argv[1:]
if "rev-parse" in args:
    print("1" * 40)
elif "archive" in args:
    with open(os.environ["MOCK_ARCHIVE"], "rb") as f:
        sys.stdout.buffer.write(f.read())
""")
        self.executable(bin_dir, "sudo", """
import os, sys
os.execvp(sys.argv[2], sys.argv[2:])
""")
        self.executable(bin_dir, "docker", """
import os, sys
if sys.argv[1] == "inspect":
    print("sha256:old" if ".Image" in sys.argv[3] else os.environ["MOCK_OLD_SITE"])
""")
        self.executable(bin_dir, "docker-compose", """
import json, os, sys
args = sys.argv[1:]
with open(os.environ["MOCK_LOG"], "a") as f:
    f.write(json.dumps(args) + "\\n")
sys.exit(1 if "up" in args and any("compose.release.json" in a for a in args) else 0)
""")
        # The real server uses flock. Use a no-op only on systems without it.
        if not shutil.which("flock"):
            self.executable(bin_dir, "flock", "pass\n")
        env = dict(
            os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
            SHINY_SERVER_DIR=str(server), MOCK_LOG=str(log),
            MOCK_ARCHIVE=str(archive), MOCK_OLD_SITE=str(old_site),
        )
        default = subprocess.run(
            ["bash", str(DEPLOY / "webhook.sh")], env=env,
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(default.returncode, 0, default.stdout + default.stderr)
        self.assertFalse(log.exists(), "Preparation must not invoke Compose")
        activated = subprocess.run(
            ["bash", str(DEPLOY / "webhook.sh"), "--deploy"], env=env,
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(activated.returncode, 1, activated.stdout + activated.stderr)
        commands = [json.loads(line) for line in log.read_text().splitlines()]
        ups = [c for c in commands if "up" in c]
        self.assertEqual(len(ups), 2)
        self.assertIn("compose.release.json", " ".join(ups[0]))
        self.assertIn("compose.previous.json", " ".join(ups[1]))
        self.assertTrue(all(c[-1] == "shiny_server" for c in ups))
        self.assertEqual(marker.read_text(), "Sin cambios")


if __name__ == "__main__":
    unittest.main()
