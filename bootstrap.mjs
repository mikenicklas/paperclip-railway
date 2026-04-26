// Auto-bootstrap the first Paperclip admin invite.
// Uses createRequire to resolve 'postgres' from @paperclipai/db's scope
// (pnpm strict mode won't resolve it from /app/ directly).
import { createHash, randomBytes } from "node:crypto";
import { createRequire } from "node:module";

const require = createRequire("/app/packages/db/");
const postgres = require("postgres");

const DB_URL = process.env.BOOTSTRAP_DB_URL || "postgres://paperclip:paperclip@127.0.0.1:54329/paperclip";
const BASE_URL = process.env.PAPERCLIP_PUBLIC_URL || `http://localhost:${process.env.PORT || 3100}`;

const sql = postgres(DB_URL);

try {
  const admins = await sql`SELECT COUNT(*) as count FROM instance_user_roles WHERE role = 'instance_admin'`;
  if (parseInt(admins[0].count) > 0) {
    console.log("Admin user already exists — skipping bootstrap.");
    process.exit(0);
  }

  await sql`
    UPDATE invites SET revoked_at = NOW(), updated_at = NOW()
    WHERE invite_type = 'bootstrap_ceo' AND revoked_at IS NULL AND accepted_at IS NULL AND expires_at > NOW()
  `;

  const token = `pcp_bootstrap_${randomBytes(24).toString("hex")}`;
  const tokenHash = createHash("sha256").update(token).digest("hex");
  const expiresAt = new Date(Date.now() + 72 * 60 * 60 * 1000);

  await sql`
    INSERT INTO invites (invite_type, token_hash, allowed_join_types, expires_at, invited_by_user_id)
    VALUES ('bootstrap_ceo', ${tokenHash}, 'human', ${expiresAt}, 'system')
  `;

  const inviteUrl = `${BASE_URL}/invite/${token}`;

  console.log("");
  console.log("========================================================");
  console.log("  ADMIN INVITE CREATED");
  console.log("========================================================");
  console.log(`  ${inviteUrl}`);
  console.log("");
  console.log(`  Expires: ${expiresAt.toISOString()}`);
  console.log("  Open this URL in your browser to create your account.");
  console.log("========================================================");
  console.log("");
} catch (err) {
  console.error("Bootstrap failed:", err.message);
} finally {
  await sql.end();
}
