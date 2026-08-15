
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  API_BASE_URL,
  clearAdminToken,
  createAchievement,
  createBook,
  createCategory,
  createMenuItem,
  createNotification,
  createReadingList,
  deleteAchievement,
  deleteBook,
  deleteCategory,
  deleteMenuItem,
  deleteNotification,
  deleteReadingList,
  getAdminBootstrap,
  getAdminSession,
  getAdminToken,
  getContentVersion,
  listStoryImages,
  loginAdmin,
  setAdminToken,
  updateAchievement,
  updateBook,
  updateCategory,
  updateMenuItem,
  updateNotification,
  updateProfile,
  updateReadingList,
  updateSupportRequest,
  updateWriteScreen,
  uploadImage,
  listAdminTags,
  createAdminTag,
  updateAdminTag,
  deleteAdminTag,
  listStoryReports,
} from "./api";
import { AuthorsPage, UsersPage } from "./moderation_pages";

const NAV = [
  { id: "dashboard", label: "Dashboard", icon: "▦" },
  { id: "novels", label: "Novels", icon: "☰" },
  { id: "authors", label: "Authors", icon: "✎" },
  { id: "users", label: "Users", icon: "☺" },
  { id: "reports", label: "Reports", icon: "▤" },
  { id: "hashtags", label: "Hashtags", icon: "#" },
  { id: "revenue", label: "Revenue", icon: "$" },
  { id: "moderation", label: "Content Moderation", icon: "◎" },
  { id: "announcements", label: "Announcements", icon: "◎" },
  { id: "settings", label: "Settings", icon: "⚙" },
];

const EMPTY_BOOK = {
  title: "",
  author: "",
  description: "",
  cover_path: "",
  accent_hex: "#3b82f6",
  section_name: "recently_updated",
  status_text: "Draft",
  rating: 0,
  genre: "",
  cta_label: "Read now",
  sort_order: 999,
};

const EMPTY_CATEGORY = { name: "", topic_count: 0, tab_group: "explore", sort_order: 999 };
const EMPTY_NOTIFICATION = { tab: "Story", title: "", message: "", created_at: "Now" };

function asArray(v) {
  return Array.isArray(v) ? v : [];
}

function statusBadge(status) {
  const s = (status || "").toLowerCase();
  if (s.includes("publish") || s === "active" || s === "approved") return "badge-green";
  if (s.includes("pending") || s.includes("review") || s.includes("draft") || s.includes("schedul"))
    return "badge-orange";
  if (s.includes("reject") || s.includes("suspend") || s.includes("inactive") || s.includes("ban"))
    return "badge-red";
  return "badge-blue";
}

function coverUrl(path) {
  if (!path) return "";
  if (path.startsWith("http")) return path;
  const base = API_BASE_URL.replace(/\/$/, "");
  return `${base}${path.startsWith("/") ? path : `/${path}`}`;
}

function BarChart({ data, color = "var(--accent)" }) {
  const max = Math.max(...data.map((d) => d.value), 1);
  return (
    <div className="bar-chart">
      {data.map((d) => (
        <div className="bar-col" key={d.label}>
          <div className="bar" style={{ height: `${(d.value / max) * 100}%`, background: color }} />
          <span className="bar-label">{d.label}</span>
        </div>
      ))}
    </div>
  );
}

function LineChart({ series }) {
  const w = 400;
  const h = 140;
  const pad = 10;
  const all = series.flatMap((s) => s.points);
  const max = Math.max(...all, 1);
  const n = series[0]?.points.length || 1;
  const toPath = (points) =>
    points
      .map((v, i) => {
        const x = pad + (i / Math.max(n - 1, 1)) * (w - pad * 2);
        const y = h - pad - (v / max) * (h - pad * 2);
        return `${i === 0 ? "M" : "L"}${x},${y}`;
      })
      .join(" ");
  return (
    <div className="line-chart">
      <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none">
        {[0.25, 0.5, 0.75].map((f) => (
          <line
            key={f}
            x1={pad}
            x2={w - pad}
            y1={h - pad - f * (h - pad * 2)}
            y2={h - pad - f * (h - pad * 2)}
            stroke="#2a3344"
            strokeWidth="1"
          />
        ))}
        {series.map((s) => (
          <path key={s.name} d={toPath(s.points)} fill="none" stroke={s.color} strokeWidth="2.5" />
        ))}
      </svg>
    </div>
  );
}

export default function App() {
  const [token, setToken] = useState(() => getAdminToken());
  const [session, setSession] = useState(null);
  const [page, setPage] = useState("dashboard");
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [contentVersion, setContentVersion] = useState("");
  const [search, setSearch] = useState("");

  const [categories, setCategories] = useState([]);
  const [books, setBooks] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const [menuItems, setMenuItems] = useState([]);
  const [writeScreen, setWriteScreen] = useState({});
  const [profile, setProfile] = useState({});
  const [readingLists, setReadingLists] = useState([]);
  const [achievements, setAchievements] = useState([]);
  const [supportRequests, setSupportRequests] = useState([]);
  const [storyImages, setStoryImages] = useState([]);

  const [loginForm, setLoginForm] = useState({ username: "", password: "" });
  const [bookModal, setBookModal] = useState(null);
  const [categoryModal, setCategoryModal] = useState(null);
  const [notifModal, setNotifModal] = useState(null);
  const [filterGenre, setFilterGenre] = useState("All");
  const [filterStatus, setFilterStatus] = useState("All");
  const [modTab, setModTab] = useState("novels");

  const toast = (msg, ok = true) => {
    setSuccess(ok ? msg : "");
    setError(ok ? "" : msg);
    setTimeout(() => {
      setSuccess("");
      setError("");
    }, 3200);
  };

  const loadAll = useCallback(async () => {
    if (!getAdminToken()) return;
    setLoading(true);
    try {
      const [sessionPayload, bootstrap, version, images] = await Promise.all([
        getAdminSession(),
        getAdminBootstrap(),
        getContentVersion(),
        listStoryImages().catch(() => ({ items: [] })),
      ]);
      setSession(sessionPayload);
      setCategories(asArray(bootstrap.categories));
      setBooks(asArray(bootstrap.books));
      setNotifications(
        asArray(bootstrap.notifications).map((n) => ({
          ...n,
          tab: n.tab ?? n.tab_name ?? "Story",
        }))
      );
      setMenuItems(asArray(bootstrap.menu_items));
      setWriteScreen(bootstrap.write_screen || {});
      setProfile(bootstrap.profile || {});
      setReadingLists(asArray(bootstrap.reading_lists));
      setAchievements(asArray(bootstrap.achievements));
      setSupportRequests(asArray(bootstrap.support_requests || bootstrap.support || []));
      setContentVersion(typeof version === "string" ? version : version?.version || "");
      setStoryImages(asArray(images.items || images));
    } catch (e) {
      if (String(e.message || e).includes("401") || String(e.message || e).includes("403")) {
        clearAdminToken();
        setToken("");
        setSession(null);
      }
      toast(String(e.message || e), false);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (token) loadAll();
  }, [token, loadAll]);

  const authors = useMemo(() => {
    const map = new Map();
    for (const b of books) {
      const name = (b.author || "Unknown").trim();
      if (!map.has(name)) {
        map.set(name, { name, novels: [], genres: new Set() });
      }
      const a = map.get(name);
      a.novels.push(b);
      if (b.genre) a.genres.add(b.genre);
    }
    return [...map.values()].map((a) => ({
      ...a,
      total: a.novels.length,
      genreFocus: [...a.genres][0] || "—",
      status: a.novels.some((n) => /publish/i.test(n.status_text || "")) ? "Active" : "Inactive",
      lastActive: "—",
      cover: a.novels[0]?.cover_path || "",
    }));
  }, [books]);

  const genres = useMemo(() => {
    const g = new Set(books.map((b) => b.genre).filter(Boolean));
    return ["All", ...g];
  }, [books]);

  const filteredBooks = useMemo(() => {
    const q = search.trim().toLowerCase();
    return books.filter((b) => {
      if (filterGenre !== "All" && b.genre !== filterGenre) return false;
      if (filterStatus !== "All" && !(b.status_text || "").toLowerCase().includes(filterStatus.toLowerCase()))
        return false;
      if (!q) return true;
      return [b.title, b.author, b.genre].some((x) => (x || "").toLowerCase().includes(q));
    });
  }, [books, search, filterGenre, filterStatus]);

  const stats = useMemo(
    () => ({
      novels: books.length,
      authors: authors.length,
      published: books.filter((b) => /publish/i.test(b.status_text || "")).length,
      pending: books.filter((b) => /pending|draft|review/i.test(b.status_text || "")).length,
      support: supportRequests.length,
      categories: categories.length,
    }),
    [books, authors, supportRequests, categories]
  );

  async function handleLogin(e) {
    e.preventDefault();
    setError("");
    try {
      const res = await loginAdmin(loginForm);
      setAdminToken(res.token);
      setToken(res.token);
      setSession({ username: res.username });
      toast("Signed in");
    } catch (err) {
      setError(String(err.message || err));
    }
  }

  function logout() {
    clearAdminToken();
    setToken("");
    setSession(null);
  }

  async function saveBook(payload, id) {
    try {
      if (id) await updateBook(id, payload);
      else await createBook(payload);
      setBookModal(null);
      toast(id ? "Novel updated" : "Novel created");
      await loadAll();
    } catch (e) {
      toast(String(e.message || e), false);
    }
  }

  async function removeBook(id) {
    if (!window.confirm("Delete this novel?")) return;
    try {
      await deleteBook(id);
      toast("Novel deleted");
      await loadAll();
    } catch (e) {
      toast(String(e.message || e), false);
    }
  }

  async function quickBookStatus(row, status_text) {
    try {
      await updateBook(row.id, { ...row, status_text });
      toast(`Status → ${status_text}`);
      await loadAll();
    } catch (e) {
      toast(String(e.message || e), false);
    }
  }

  if (!token) {
    return (
      <div className="login-page">
        <form className="login-card" onSubmit={handleLogin}>
          <div className="brand" style={{ padding: 0, marginBottom: 12 }}>
            <div className="brand-mark">N</div>
            NovelHub Admin
          </div>
          <h1>Sign in</h1>
          <p>Manage novels, authors, users, and content.</p>
          {error && <div className="login-error">{error}</div>}
          <label>Username</label>
          <input
            value={loginForm.username}
            onChange={(e) => setLoginForm((f) => ({ ...f, username: e.target.value }))}
            autoComplete="username"
            required
          />
          <label>Password</label>
          <input
            type="password"
            value={loginForm.password}
            onChange={(e) => setLoginForm((f) => ({ ...f, password: e.target.value }))}
            autoComplete="current-password"
            required
          />
          <button type="submit">Login</button>
          <p style={{ marginTop: 14, fontSize: ".75rem" }}>
            Credentials from backend <code>.env</code> (<code>ADMIN_USERNAME</code> / <code>ADMIN_PASSWORD</code>)
          </p>
        </form>
      </div>
    );
  }

  const pageTitle = NAV.find((n) => n.id === page)?.label || "Dashboard";

  return (
    <div className="app-shell">
      {sidebarOpen && <div className="sidebar-backdrop" onClick={() => setSidebarOpen(false)} />}
      <aside className={`sidebar ${sidebarOpen ? "open" : ""}`}>
        <div className="brand">
          <div className="brand-mark">N</div>
          <div>
            <div>NovelHub</div>
            <div style={{ fontSize: ".7rem", color: "var(--text-muted)", fontWeight: 400 }}>Admin Dashboard</div>
          </div>
        </div>
        <ul className="nav-list">
          {NAV.map((n) => (
            <li key={n.id}>
              <button
                type="button"
                className={`nav-item ${page === n.id ? "active" : ""}`}
                onClick={() => {
                  setPage(n.id);
                  setSidebarOpen(false);
                }}
              >
                <span className="nav-icon">{n.icon}</span>
                {n.label}
              </button>
            </li>
          ))}
        </ul>
        <button type="button" className="btn" style={{ marginTop: 12 }} onClick={logout}>
          Sign out
        </button>
      </aside>

      <div className="main-col">
        <header className="topbar">
          <button type="button" className="mobile-menu-btn" onClick={() => setSidebarOpen(true)}>
            ☰
          </button>
          <h1>{pageTitle}</h1>
          <div className="top-search">
            <input
              placeholder="Search novels, authors, users…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="top-actions">
            <button type="button" className="btn btn-sm" onClick={loadAll} disabled={loading}>
              {loading ? "Sync…" : "Refresh"}
            </button>
            <div className="icon-btn" title="Notifications">
              🔔
              {stats.pending > 0 && <span className="badge-dot">{Math.min(stats.pending, 9)}</span>}
            </div>
            <div className="user-chip">
              <div className="avatar-fallback">{(session?.username || "A")[0].toUpperCase()}</div>
              <div>
                <div style={{ fontWeight: 600 }}>{session?.username || "Admin"}</div>
                <div style={{ fontSize: ".7rem", color: "var(--text-muted)" }}>v{contentVersion || "—"}</div>
              </div>
            </div>
          </div>
        </header>

        <main className="content">
          {page === "dashboard" && (
            <Dashboard
              stats={stats}
              books={books}
              authors={authors}
              supportRequests={supportRequests}
              onReview={(b) => {
                setPage("novels");
                setBookModal(b);
              }}
              onGoto={(p) => setPage(p)}
            />
          )}
          {page === "novels" && (
            <NovelsPage
              books={filteredBooks}
              genres={genres}
              filterGenre={filterGenre}
              setFilterGenre={setFilterGenre}
              filterStatus={filterStatus}
              setFilterStatus={setFilterStatus}
              onCreate={() => setBookModal({ ...EMPTY_BOOK })}
              onEdit={(b) => setBookModal({ ...b })}
              onDelete={removeBook}
              onStatus={quickBookStatus}
              storyImages={storyImages}
            />
          )}
          {page === "authors" && <AuthorsPage authors={authors} search={search} />}
          {page === "users" && (
            <UsersPage profile={profile} supportRequests={supportRequests} onUpdateSupport={async (id, p) => {
              await updateSupportRequest(id, p);
              toast("Updated");
              loadAll();
            }} />
          )}
          {page === "reports" && <StoryReportsPage />}
          {page === "hashtags" && <HashtagsPage />}
          {page === "revenue" && <RevenuePage books={books} />}
          {page === "moderation" && (
            <ModerationPage
              books={books}
              supportRequests={supportRequests}
              modTab={modTab}
              setModTab={setModTab}
              onStatus={quickBookStatus}
              onSupport={async (id, status) => {
                await updateSupportRequest(id, { status });
                toast("Request updated");
                loadAll();
              }}
            />
          )}
          {page === "announcements" && (
            <AnnouncementsPage
              items={notifications}
              onCreate={() => setNotifModal({ ...EMPTY_NOTIFICATION })}
              onEdit={(n) => setNotifModal({ ...n })}
              onDelete={async (id) => {
                if (!window.confirm("Delete announcement?")) return;
                await deleteNotification(id);
                toast("Deleted");
                loadAll();
              }}
            />
          )}
          {page === "settings" && (
            <SettingsPage
              categories={categories}
              writeScreen={writeScreen}
              profile={profile}
              readingLists={readingLists}
              achievements={achievements}
              menuItems={menuItems}
              onSaveCategory={async (payload, id) => {
                if (id) await updateCategory(id, payload);
                else await createCategory(payload);
                toast("Category saved");
                setCategoryModal(null);
                loadAll();
              }}
              onDeleteCategory={async (id) => {
                if (!window.confirm("Delete category?")) return;
                await deleteCategory(id);
                toast("Deleted");
                loadAll();
              }}
              onSaveWrite={async (p) => {
                await updateWriteScreen(p);
                toast("Write screen saved — Flutter will pick up on next sync");
                loadAll();
              }}
              onSaveProfile={async (p) => {
                await updateProfile(p);
                toast("Profile defaults saved");
                loadAll();
              }}
              openCategory={() => setCategoryModal({ ...EMPTY_CATEGORY })}
              editCategory={(c) => setCategoryModal({ ...c })}
            />
          )}
        </main>
      </div>

      {bookModal && (
        <BookModal
          book={bookModal}
          storyImages={storyImages}
          onClose={() => setBookModal(null)}
          onSave={saveBook}
          onUpload={async (file) => {
            const res = await uploadImage(file);
            return res.path || res.cover_path || res.url || "";
          }}
        />
      )}
      {categoryModal && (
        <CategoryModal
          item={categoryModal}
          onClose={() => setCategoryModal(null)}
          onSave={async (p) => {
            if (categoryModal.id) await updateCategory(categoryModal.id, p);
            else await createCategory(p);
            toast("Category saved");
            setCategoryModal(null);
            loadAll();
          }}
        />
      )}
      {notifModal && (
        <NotifModal
          item={notifModal}
          onClose={() => setNotifModal(null)}
          onSave={async (p) => {
            if (notifModal.id) await updateNotification(notifModal.id, p);
            else await createNotification(p);
            toast("Announcement saved — visible after app content sync");
            setNotifModal(null);
            loadAll();
          }}
        />
      )}

      {(success || error) && (
        <div className={`toast ${error ? "err" : "ok"}`}>{error || success}</div>
      )}
    </div>
  );
}

function Dashboard({ stats, books, authors, supportRequests, onReview, onGoto }) {
  const genreCounts = useMemo(() => {
    const m = {};
    for (const b of books) {
      const g = b.genre || "Other";
      m[g] = (m[g] || 0) + 1;
    }
    return Object.entries(m)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([label, value]) => ({ label: label.slice(0, 8), value }));
  }, [books]);

  const lineSeries = [
    {
      name: "Novels",
      color: "#3b82f6",
      points: [30, 45, 40, 60, 55, 70, 65, 80, 75, 90, 95, 110],
    },
    {
      name: "Reads",
      color: "#14b8a6",
      points: [20, 35, 50, 45, 60, 70, 65, 85, 90, 100, 120, 140],
    },
  ];

  const pending = books.filter((b) => /pending|draft|review/i.test(b.status_text || "")).slice(0, 5);

  return (
    <>
      <div className="stats-row">
        <div className="stat-card">
          <div className="label"><span className="stat-icon">▣</span> Total Novels</div>
          <p className="value">{stats.novels}</p>
          <div className="trend">{stats.published} published</div>
        </div>
        <div className="stat-card">
          <div className="label"><span className="stat-icon">✎</span> Active Authors</div>
          <p className="value">{stats.authors}</p>
          <div className="trend">From story authors</div>
        </div>
        <div className="stat-card">
          <div className="label"><span className="stat-icon">＋</span> Pending Review</div>
          <p className="value">{stats.pending}</p>
          <div className="trend" style={{ color: "var(--orange)" }}>Needs attention</div>
        </div>
        <div className="stat-card">
          <div className="label"><span className="stat-icon">✉</span> Support</div>
          <p className="value">{stats.support}</p>
          <div className="trend">{stats.categories} categories</div>
        </div>
      </div>

      <div className="panel-grid">
        <div className="panel">
          <div className="panel-header">
            <h3>Novel Performance Overview</h3>
            <span className="meta">Illustrative trend</span>
          </div>
          <LineChart series={lineSeries} />
        </div>
        <div className="panel">
          <div className="panel-header">
            <h3>Content Moderation Queue</h3>
            <span className="meta">{pending.length} pending</span>
          </div>
          <div className="table-wrap">
            <table className="data">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Author</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {pending.length === 0 && (
                  <tr><td colSpan={4} className="empty">Queue empty</td></tr>
                )}
                {pending.map((b) => (
                  <tr key={b.id}>
                    <td>{b.title}</td>
                    <td>{b.author}</td>
                    <td><span className={`badge ${statusBadge(b.status_text)}`}>{b.status_text || "—"}</span></td>
                    <td>
                      <button type="button" className="btn btn-sm btn-primary" onClick={() => onReview(b)}>
                        Review
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div className="panel-grid-3">
        <div className="panel">
          <div className="panel-header"><h3>Top Genres</h3></div>
          <BarChart data={genreCounts.length ? genreCounts : [{ label: "—", value: 1 }]} />
        </div>
        <div className="panel">
          <div className="panel-header"><h3>Recent Activity</h3></div>
          {books.slice(0, 5).map((b) => (
            <div className="activity-item" key={b.id}>
              <div className="avatar-fallback" style={{ width: 28, height: 28, fontSize: 10 }}>
                {(b.author || "?")[0]}
              </div>
              <div>
                <strong>{b.author}</strong> — {b.title}
              </div>
            </div>
          ))}
          {books.length === 0 && <div className="empty">No activity yet</div>}
        </div>
        <div className="panel">
          <div className="panel-header">
            <h3>Quick links</h3>
          </div>
          <div className="btn-row" style={{ flexDirection: "column", alignItems: "stretch" }}>
            <button type="button" className="btn" onClick={() => onGoto("novels")}>Manage novels</button>
            <button type="button" className="btn" onClick={() => onGoto("moderation")}>Content moderation</button>
            <button type="button" className="btn" onClick={() => onGoto("announcements")}>Announcements</button>
            <button type="button" className="btn" onClick={() => onGoto("settings")}>Settings & categories</button>
          </div>
        </div>
      </div>
    </>
  );
}

function NovelsPage({
  books,
  genres,
  filterGenre,
  setFilterGenre,
  filterStatus,
  setFilterStatus,
  onCreate,
  onEdit,
  onDelete,
  onStatus,
}) {
  return (
    <div className="layout-with-aside">
      <div>
        <div className="toolbar">
          <select value={filterGenre} onChange={(e) => setFilterGenre(e.target.value)}>
            {genres.map((g) => (
              <option key={g} value={g}>{g === "All" ? "All Genres" : g}</option>
            ))}
          </select>
          <select value={filterStatus} onChange={(e) => setFilterStatus(e.target.value)}>
            {["All", "Published", "Draft", "Pending"].map((s) => (
              <option key={s} value={s}>{s === "All" ? "All Status" : s}</option>
            ))}
          </select>
          <button type="button" className="btn btn-primary" onClick={onCreate} style={{ marginLeft: "auto" }}>
            Create New Novel
          </button>
        </div>
        <div className="panel">
          <div className="table-wrap">
            <table className="data">
              <thead>
                <tr>
                  <th>Cover</th>
                  <th>Title</th>
                  <th>Author</th>
                  <th>Genre</th>
                  <th>Status</th>
                  <th>Rating</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {books.map((b) => (
                  <tr key={b.id}>
                    <td>
                      {b.cover_path ? (
                        <img className="cover-thumb" src={coverUrl(b.cover_path)} alt="" />
                      ) : (
                        <div className="cover-thumb" />
                      )}
                    </td>
                    <td style={{ fontWeight: 600 }}>{b.title}</td>
                    <td>{b.author}</td>
                    <td>{b.genre || "—"}</td>
                    <td><span className={`badge ${statusBadge(b.status_text)}`}>{b.status_text || "—"}</span></td>
                    <td>{b.rating ?? "—"}</td>
                    <td>
                      <div className="btn-row">
                        <button type="button" className="btn btn-sm" onClick={() => onEdit(b)}>Edit</button>
                        {!/publish/i.test(b.status_text || "") && (
                          <button type="button" className="btn btn-sm btn-primary" onClick={() => onStatus(b, "Published")}>
                            Publish
                          </button>
                        )}
                        <button type="button" className="btn btn-sm btn-danger" onClick={() => onDelete(b.id)}>
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {books.length === 0 && (
                  <tr><td colSpan={7} className="empty">No novels match filters</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <div className="aside-stack">
        <div className="panel">
          <div className="panel-header"><h3>Recent Novels</h3></div>
          {books.slice(0, 6).map((b) => (
            <div className="activity-item" key={b.id}>
              {b.cover_path ? (
                <img className="cover-thumb" style={{ width: 28, height: 40 }} src={coverUrl(b.cover_path)} alt="" />
              ) : (
                <div className="cover-thumb" style={{ width: 28, height: 40 }} />
              )}
              <div>
                <div style={{ fontWeight: 600, fontSize: ".8rem" }}>{b.title}</div>
                <div style={{ color: "var(--text-muted)", fontSize: ".72rem" }}>{b.author}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function StoryReportsPage() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const data = await listStoryReports();
      setItems(Array.isArray(data?.items) ? data.items : []);
    } catch (e) {
      setError(e.message || "Failed to load reports");
      setItems([]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  const flagged = items.filter((r) => Number(r.report_count || 0) >= 3);

  return (
    <>
      <div className="stats-row">
        <div className="stat-card"><div className="label">Reported stories</div><p className="value">{items.length}</p></div>
        <div className="stat-card"><div className="label">Flagged (3+ reports)</div><p className="value">{flagged.length}</p></div>
        <div className="stat-card"><div className="label">Rule</div><p className="value" style={{fontSize:14}}>3 unique accounts</p></div>
      </div>
      <div className="panel">
        <div className="panel-header">
          <h3>Story reports</h3>
          <button type="button" className="btn-ghost" onClick={load}>Refresh</button>
        </div>
        {error && <div className="error-banner">{error}</div>}
        {loading ? <p>Loading…</p> : (
          <div className="table-wrap">
            <table className="data">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Author</th>
                  <th>Reports</th>
                  <th>Status</th>
                  <th>Last report</th>
                </tr>
              </thead>
              <tbody>
                {items.length === 0 && (
                  <tr><td colSpan={5} style={{color:"var(--text-muted)"}}>No reports yet. Stories appear here after users report them.</td></tr>
                )}
                {items.map((r) => (
                  <tr key={r.book_id} style={Number(r.report_count)>=3 ? {background:"#fff5f5"} : undefined}>
                    <td><strong>{r.title || `#${r.book_id}`}</strong></td>
                    <td>{r.author || "—"}</td>
                    <td>
                      <span className={Number(r.report_count)>=3 ? "badge danger" : "badge"}>
                        {r.report_count}
                      </span>
                      {Number(r.report_count)>=3 ? " · Admin queue" : ""}
                    </td>
                    <td>{r.status_text || "—"}</td>
                    <td>{r.last_report_at ? String(r.last_report_at).slice(0,19) : "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}

function HashtagsPage() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [name, setName] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function load() {
    setLoading(true);
    setError("");
    try {
      const data = await listAdminTags();
      setItems(Array.isArray(data?.items) ? data.items : []);
    } catch (e) {
      setError(e.message || "Failed to load hashtags");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  async function onCreate(e) {
    e.preventDefault();
    const n = name.trim().replace(/^#/, "");
    if (!n) return;
    setBusy(true);
    setError("");
    try {
      await createAdminTag({ name: n });
      setName("");
      await load();
    } catch (err) {
      setError(err.message || "Create failed");
    } finally {
      setBusy(false);
    }
  }

  async function onRename(tag) {
    const next = window.prompt("Rename hashtag", tag.name);
    if (!next || !next.trim()) return;
    setBusy(true);
    try {
      await updateAdminTag(tag.id, { name: next.trim().replace(/^#/, "") });
      await load();
    } catch (err) {
      setError(err.message || "Update failed");
    } finally {
      setBusy(false);
    }
  }

  async function onDelete(tag) {
    if (!window.confirm(`Delete #${tag.name}? Stories will lose this tag.`)) return;
    setBusy(true);
    try {
      await deleteAdminTag(tag.id);
      await load();
    } catch (err) {
      setError(err.message || "Delete failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="panel">
        <div className="panel-header"><h3>Hashtag management</h3></div>
        <p style={{color:"var(--text-muted)", marginBottom:12}}>
          Authors can only attach hashtags you create here (max 3 per story).
        </p>
        <form onSubmit={onCreate} style={{display:"flex", gap:8, marginBottom:16, flexWrap:"wrap"}}>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="New hashtag (without #)"
            style={{flex:1, minWidth:180}}
          />
          <button type="submit" className="btn-primary" disabled={busy}>Add hashtag</button>
          <button type="button" className="btn-ghost" onClick={load}>Refresh</button>
        </form>
        {error && <div className="error-banner">{error}</div>}
        {loading ? <p>Loading…</p> : (
          <div className="table-wrap">
            <table className="data">
              <thead>
                <tr><th>Hashtag</th><th>Stories</th><th>Actions</th></tr>
              </thead>
              <tbody>
                {items.length === 0 && (
                  <tr><td colSpan={3} style={{color:"var(--text-muted)"}}>No hashtags yet. Add the first one.</td></tr>
                )}
                {items.map((t) => (
                  <tr key={t.id}>
                    <td><strong>#{t.name}</strong></td>
                    <td>{t.book_count ?? 0}</td>
                    <td style={{display:"flex", gap:8}}>
                      <button type="button" className="btn-ghost" onClick={() => onRename(t)} disabled={busy}>Rename</button>
                      <button type="button" className="btn-danger" onClick={() => onDelete(t)} disabled={busy}>Delete</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}

function RevenuePage({ books }) {
  const demo = [
    { label: "Jan", value: 40 },
    { label: "Feb", value: 55 },
    { label: "Mar", value: 48 },
    { label: "Apr", value: 70 },
    { label: "May", value: 62 },
    { label: "Jun", value: 85 },
  ];
  return (
    <>
      <div className="stats-row">
        <div className="stat-card"><div className="label">Catalog size</div><p className="value">{books.length}</p>
          <div className="trend">Live from DB</div></div>
        <div className="stat-card"><div className="label">Published</div>
          <p className="value">{books.filter((b) => /publish/i.test(b.status_text || "")).length}</p></div>
        <div className="stat-card"><div className="label">Illustrative revenue</div><p className="value">—</p>
          <div className="trend">Wire payments when ready</div></div>
        <div className="stat-card"><div className="label">In-app</div><p className="value">—</p></div>
      </div>
      <div className="panel">
        <div className="panel-header"><h3>Monthly overview (placeholder chart)</h3></div>
        <BarChart data={demo} />
      </div>
    </>
  );
}

function ModerationPage({ books, supportRequests, modTab, setModTab, onStatus, onSupport }) {
  const pending = books.filter((b) => /pending|draft|review/i.test(b.status_text || ""));
  return (
    <>
      <div className="tabs">
        <button type="button" className={`tab ${modTab === "novels" ? "active" : ""}`} onClick={() => setModTab("novels")}>
          Novels ({pending.length} pending)
        </button>
        <button type="button" className={`tab ${modTab === "support" ? "active" : ""}`} onClick={() => setModTab("support")}>
          Support ({supportRequests.length})
        </button>
      </div>
      {modTab === "novels" && (
        <div className="panel">
          <table className="data">
            <thead>
              <tr><th>Title</th><th>Author</th><th>Status</th><th>Actions</th></tr>
            </thead>
            <tbody>
              {pending.map((b) => (
                <tr key={b.id}>
                  <td>{b.title}</td>
                  <td>{b.author}</td>
                  <td><span className={`badge ${statusBadge(b.status_text)}`}>{b.status_text}</span></td>
                  <td className="btn-row">
                    <button type="button" className="btn btn-sm btn-primary" onClick={() => onStatus(b, "Published")}>Approve</button>
                    <button type="button" className="btn btn-sm btn-danger" onClick={() => onStatus(b, "Rejected")}>Reject</button>
                  </td>
                </tr>
              ))}
              {pending.length === 0 && <tr><td colSpan={4} className="empty">Nothing pending</td></tr>}
            </tbody>
          </table>
        </div>
      )}
      {modTab === "support" && (
        <div className="panel">
          <table className="data">
            <thead>
              <tr><th>Email</th><th>Subject</th><th>Status</th><th>Actions</th></tr>
            </thead>
            <tbody>
              {supportRequests.map((r) => (
                <tr key={r.id}>
                  <td>{r.email}</td>
                  <td>{r.subject || r.issue}</td>
                  <td><span className={`badge ${statusBadge(r.status)}`}>{r.status || "open"}</span></td>
                  <td className="btn-row">
                    <button type="button" className="btn btn-sm" onClick={() => onSupport(r.id, "resolved")}>Resolve</button>
                    <button type="button" className="btn btn-sm" onClick={() => onSupport(r.id, "closed")}>Close</button>
                  </td>
                </tr>
              ))}
              {supportRequests.length === 0 && <tr><td colSpan={4} className="empty">No support tickets</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

function AnnouncementsPage({ items, onCreate, onEdit, onDelete }) {
  return (
    <>
      <div className="toolbar">
        <button type="button" className="btn btn-primary" onClick={onCreate} style={{ marginLeft: "auto" }}>
          Create New Announcement
        </button>
      </div>
      <div className="panel">
        <table className="data">
          <thead>
            <tr><th>Title</th><th>Tab</th><th>Message</th><th>When</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {items.map((n) => (
              <tr key={n.id}>
                <td style={{ fontWeight: 600 }}>{n.title}</td>
                <td>{n.tab || n.tab_name}</td>
                <td style={{ maxWidth: 280 }}>{(n.message || "").slice(0, 80)}</td>
                <td>{n.created_at}</td>
                <td className="btn-row">
                  <button type="button" className="btn btn-sm" onClick={() => onEdit(n)}>Edit</button>
                  <button type="button" className="btn btn-sm btn-danger" onClick={() => onDelete(n.id)}>Delete</button>
                </td>
              </tr>
            ))}
            {items.length === 0 && <tr><td colSpan={5} className="empty">No announcements</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}

function SettingsPage({
  categories,
  writeScreen,
  profile,
  onSaveCategory,
  onDeleteCategory,
  onSaveWrite,
  onSaveProfile,
  openCategory,
  editCategory,
}) {
  const [ws, setWs] = useState(writeScreen);
  const [pf, setPf] = useState(profile);
  useEffect(() => setWs(writeScreen), [writeScreen]);
  useEffect(() => setPf(profile), [profile]);

  return (
    <div className="layout-with-aside">
      <div className="aside-stack">
        <div className="panel">
          <div className="panel-header">
            <h3>Categories / Genres</h3>
            <button type="button" className="btn btn-sm btn-primary" onClick={openCategory}>Add</button>
          </div>
          <table className="data">
            <thead><tr><th>Name</th><th>Group</th><th></th></tr></thead>
            <tbody>
              {categories.map((c) => (
                <tr key={c.id}>
                  <td>{c.name}</td>
                  <td>{c.tab_group}</td>
                  <td className="btn-row">
                    <button type="button" className="btn btn-sm" onClick={() => editCategory(c)}>Edit</button>
                    <button type="button" className="btn btn-sm btn-danger" onClick={() => onDeleteCategory(c.id)}>Del</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="panel">
          <div className="panel-header"><h3>Write screen labels</h3></div>
          <div className="field" style={{ marginBottom: 8 }}>
            <label>Filter label</label>
            <input value={ws.filter_label || ""} onChange={(e) => setWs({ ...ws, filter_label: e.target.value })} />
          </div>
          <div className="field" style={{ marginBottom: 8 }}>
            <label>Sort label</label>
            <input value={ws.sort_label || ""} onChange={(e) => setWs({ ...ws, sort_label: e.target.value })} />
          </div>
          <div className="field" style={{ marginBottom: 8 }}>
            <label>Empty title</label>
            <input value={ws.empty_title || ""} onChange={(e) => setWs({ ...ws, empty_title: e.target.value })} />
          </div>
          <button type="button" className="btn btn-primary" onClick={() => onSaveWrite(ws)}>Save write screen</button>
        </div>
      </div>
      <div className="panel">
        <div className="panel-header"><h3>Default profile stats</h3></div>
        <div className="form-grid">
          <div className="field"><label>Display name</label>
            <input value={pf.display_name || ""} onChange={(e) => setPf({ ...pf, display_name: e.target.value })} /></div>
          <div className="field"><label>Username</label>
            <input value={pf.username || ""} onChange={(e) => setPf({ ...pf, username: e.target.value })} /></div>
          <div className="field"><label>Following</label>
            <input type="number" value={pf.following ?? 0} onChange={(e) => setPf({ ...pf, following: Number(e.target.value) })} /></div>
          <div className="field"><label>Followers</label>
            <input type="number" value={pf.followers ?? 0} onChange={(e) => setPf({ ...pf, followers: Number(e.target.value) })} /></div>
        </div>
        <button type="button" className="btn btn-primary" style={{ marginTop: 12 }} onClick={() => onSaveProfile(pf)}>
          Save profile defaults
        </button>
        <p style={{ marginTop: 16, fontSize: ".8rem", color: "var(--text-muted)" }}>
          Changes write to the database via <code>/api/admin/*</code>. The Flutter app polls content version and reloads bootstrap — novels, categories, and notifications appear in Discover / Library after sync.
        </p>
      </div>
    </div>
  );
}

function BookModal({ book, storyImages, onClose, onSave, onUpload }) {
  const [form, setForm] = useState(book);
  const [uploading, setUploading] = useState(false);
  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>{book.id ? "Edit novel" : "Create novel"}</h2>
        <div className="form-grid">
          <div className="field full"><label>Title</label>
            <input value={form.title} onChange={(e) => set("title", e.target.value)} /></div>
          <div className="field"><label>Author</label>
            <input value={form.author} onChange={(e) => set("author", e.target.value)} /></div>
          <div className="field"><label>Genre</label>
            <input value={form.genre || ""} onChange={(e) => set("genre", e.target.value)} /></div>
          <div className="field"><label>Status</label>
            <select value={form.status_text || "Draft"} onChange={(e) => set("status_text", e.target.value)}>
              {["Draft", "Pending Review", "Published", "Rejected"].map((s) => (
                <option key={s}>{s}</option>
              ))}
            </select>
          </div>
          <div className="field"><label>Section</label>
            <select value={form.section_name || "recently_updated"} onChange={(e) => set("section_name", e.target.value)}>
              {["recently_updated", "recently_completed", "discover", "popular"].map((s) => (
                <option key={s}>{s}</option>
              ))}
            </select>
          </div>
          <div className="field"><label>Rating</label>
            <input type="number" step="0.1" value={form.rating ?? 0} onChange={(e) => set("rating", Number(e.target.value))} /></div>
          <div className="field full"><label>Description</label>
            <textarea value={form.description || ""} onChange={(e) => set("description", e.target.value)} /></div>
          <div className="field full"><label>Cover path</label>
            <input value={form.cover_path || ""} onChange={(e) => set("cover_path", e.target.value)} />
            <input
              type="file"
              accept="image/*"
              style={{ marginTop: 8 }}
              onChange={async (e) => {
                const file = e.target.files?.[0];
                if (!file) return;
                setUploading(true);
                try {
                  const path = await onUpload(file);
                  if (path) set("cover_path", path);
                } finally {
                  setUploading(false);
                }
              }}
            />
            {uploading && <span style={{ fontSize: ".8rem" }}>Uploading…</span>}
          </div>
        </div>
        <div className="modal-actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button type="button" className="btn btn-primary" onClick={() => onSave(form, book.id)}>
            Save
          </button>
        </div>
      </div>
    </div>
  );
}

function CategoryModal({ item, onClose, onSave }) {
  const [form, setForm] = useState(item);
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>{item.id ? "Edit category" : "New category"}</h2>
        <div className="field" style={{ marginBottom: 8 }}>
          <label>Name</label>
          <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
        </div>
        <div className="field" style={{ marginBottom: 8 }}>
          <label>Tab group</label>
          <input value={form.tab_group || ""} onChange={(e) => setForm({ ...form, tab_group: e.target.value })} />
        </div>
        <div className="modal-actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button type="button" className="btn btn-primary" onClick={() => onSave(form)}>Save</button>
        </div>
      </div>
    </div>
  );
}

function NotifModal({ item, onClose, onSave }) {
  const [form, setForm] = useState(item);
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>{item.id ? "Edit announcement" : "New announcement"}</h2>
        <div className="field" style={{ marginBottom: 8 }}>
          <label>Title</label>
          <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
        </div>
        <div className="field" style={{ marginBottom: 8 }}>
          <label>Tab</label>
          <input value={form.tab || ""} onChange={(e) => setForm({ ...form, tab: e.target.value })} />
        </div>
        <div className="field" style={{ marginBottom: 8 }}>
          <label>Message</label>
          <textarea value={form.message || ""} onChange={(e) => setForm({ ...form, message: e.target.value })} />
        </div>
        <div className="modal-actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button type="button" className="btn btn-primary" onClick={() => onSave(form)}>Save</button>
        </div>
      </div>
    </div>
  );
}
