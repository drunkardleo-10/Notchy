import Foundation

enum OpenCodePlugin {
    private static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/opencode/plugins/notchy.js")

    private static let source = """
    import { mkdirSync, writeFileSync, renameSync, unlinkSync, readFileSync } from "fs";
    import { homedir } from "os";
    import { join, basename } from "path";

    const dir = join(homedir(), ".notchy", "agents");

    export default async ({ directory }) => {
      const cwds = new Map();
      const busy = new Set();
      const file = (sid) => join(dir, "opencode-" + String(sid).replace(/[^A-Za-z0-9_-]/g, "") + ".json");
      const write = (sid, state, tool = "") => {
        try {
          mkdirSync(dir, { recursive: true });
          const path = file(sid);
          let prev = {};
          try { prev = JSON.parse(readFileSync(path, "utf8")); } catch {}
          const cwd = cwds.get(sid) || prev.cwd || directory || "";
          const out = { id: basename(path, ".json"), agent: "opencode", cwd, project: basename(cwd) || "OpenCode", state, tool, message: "", updated: Date.now() / 1000 };
          writeFileSync(path + ".tmp", JSON.stringify(out));
          renameSync(path + ".tmp", path);
        } catch {}
      };
      const remove = (sid) => { try { unlinkSync(file(sid)); } catch {} };

      return {
        event: async ({ event }) => {
          try {
            const t = event.type;
            const p = event.properties || {};
            if ((t === "session.created" || t === "session.updated") && p.info) {
              if (p.info.directory) cwds.set(p.info.id, p.info.directory);
              if (p.info.time && p.info.time.archived) remove(p.info.id);
              return;
            }
            if (t === "session.deleted" && p.info) {
              busy.delete(p.info.id);
              remove(p.info.id);
              return;
            }
            if (t === "session.status" && p.sessionID) {
              const kind = p.status && p.status.type;
              if (kind === "busy") {
                busy.add(p.sessionID);
                write(p.sessionID, "working");
              } else if (kind === "idle" && busy.has(p.sessionID)) {
                busy.delete(p.sessionID);
                write(p.sessionID, "done");
              }
              return;
            }
            if (t === "session.idle" && p.sessionID && busy.has(p.sessionID)) {
              busy.delete(p.sessionID);
              write(p.sessionID, "done");
              return;
            }
            if (t === "message.part.updated" && p.part && p.part.type === "tool" && p.part.sessionID) {
              const status = p.part.state && p.part.state.status;
              if (status === "running" || status === "pending") {
                busy.add(p.part.sessionID);
                write(p.part.sessionID, "working", p.part.tool || "");
              }
              return;
            }
            if (t === "permission.asked" && p.sessionID) {
              write(p.sessionID, "attention");
              return;
            }
            if (t === "permission.replied" && p.sessionID) {
              write(p.sessionID, "working");
            }
          } catch {}
        },
      };
    };
    """

    static var isInstalled: Bool {
        (try? String(contentsOf: url, encoding: .utf8)) == source
    }

    @discardableResult
    static func install() -> Bool {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? source.write(to: url, atomically: true, encoding: .utf8)) != nil
    }
}
