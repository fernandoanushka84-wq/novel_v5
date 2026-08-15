
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL?.trim() || "http://127.0.0.1:8000";
const ADMIN_TOKEN_KEY = "novel_admin_token";

export function getAdminToken() {
  return window.localStorage.getItem(ADMIN_TOKEN_KEY) || "";
}

export function setAdminToken(token) {
  if (!token) {
    window.localStorage.removeItem(ADMIN_TOKEN_KEY);
    return;
  }
  window.localStorage.setItem(ADMIN_TOKEN_KEY, token);
}

export function clearAdminToken() {
  window.localStorage.removeItem(ADMIN_TOKEN_KEY);
}

async function request(path, options = {}) {
  const headers = { ...(options.headers || {}) };
  const token = getAdminToken();
  if (token && !headers.Authorization) {
    headers.Authorization = `Bearer ${token}`;
  }

  const isFormData = options.body instanceof FormData;
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: {
      ...(isFormData ? {} : { "Content-Type": "application/json" }),
      ...headers,
    },
    ...options,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `Request failed with status ${response.status}`);
  }

  if (response.status === 204) return null;
  return response.json();
}

export function loginAdmin(payload) {
  return request("/api/admin/login", { method: "POST", body: JSON.stringify(payload) });
}

export function getAdminSession() {
  // Backend only allows POST (Bearer token in Authorization header).
  return request("/api/admin/session", { method: "POST", body: "{}" });
}

export function getContentVersion() {
  return request("/api/content/version");
}

export function listStoryImages() {
  return request("/api/story-images");
}

export function uploadImage(file) {
  const body = new FormData();
  body.append("file", file);
  return request("/api/upload-image", { method: "POST", body });
}

export function getAdminBootstrap() {
  return request("/api/admin/bootstrap");
}

export function createCategory(payload) {
  return request("/api/admin/categories", { method: "POST", body: JSON.stringify(payload) });
}

export function updateCategory(id, payload) {
  return request(`/api/admin/categories/${id}`, { method: "PUT", body: JSON.stringify(payload) });
}

export function deleteCategory(id) {
  return request(`/api/admin/categories/${id}`, { method: "DELETE" });
}

export function createBook(payload) {
  return request("/api/admin/books", { method: "POST", body: JSON.stringify(payload) });
}

export function updateBook(id, payload) {
  return request(`/api/admin/books/${id}`, { method: "PUT", body: JSON.stringify(payload) });
}

export function deleteBook(id) {
  return request(`/api/admin/books/${id}`, { method: "DELETE" });
}

export function createNotification(payload) {
  return request("/api/admin/notifications", {
    method: "POST",
    body: JSON.stringify({
      tab_name: payload.tab ?? payload.tab_name ?? "activity",
      title: payload.title ?? "",
      message: payload.message ?? "",
      created_at: payload.created_at ?? "Now",
      sort_order: payload.sort_order ?? 999,
    }),
  });
}

export function updateNotification(id, payload) {
  return request(`/api/admin/notifications/${id}`, {
    method: "PUT",
    body: JSON.stringify({
      tab_name: payload.tab ?? payload.tab_name,
      title: payload.title,
      message: payload.message,
      created_at: payload.created_at,
      sort_order: payload.sort_order,
    }),
  });
}

export function deleteNotification(id) {
  return request(`/api/admin/notifications/${id}`, { method: "DELETE" });
}

export function createMenuItem(payload) {
  return request("/api/admin/menu-items", {
    method: "POST",
    body: JSON.stringify({
      section_name: payload.section ?? payload.section_name ?? "General",
      section_order: payload.section_order ?? 1,
      label: payload.label ?? "",
      icon_name: payload.icon ?? payload.icon_name ?? "menu",
      route_name: payload.route ?? payload.route_name ?? "/",
      sort_order: payload.sort_order ?? 999,
    }),
  });
}

export function updateMenuItem(id, payload) {
  return request(`/api/admin/menu-items/${id}`, {
    method: "PUT",
    body: JSON.stringify({
      section_name: payload.section ?? payload.section_name,
      section_order: payload.section_order,
      label: payload.label,
      icon_name: payload.icon ?? payload.icon_name,
      route_name: payload.route ?? payload.route_name,
      sort_order: payload.sort_order,
    }),
  });
}

export function deleteMenuItem(id) {
  return request(`/api/admin/menu-items/${id}`, { method: "DELETE" });
}

export function updateWriteScreen(payload) {
  return request("/api/admin/write-screen", {
    method: "PUT",
    body: JSON.stringify({
      manage_tabs: Array.isArray(payload.manage_tabs)
        ? payload.manage_tabs.join(",")
        : payload.manage_tabs,
      story_tabs: Array.isArray(payload.story_tabs)
        ? payload.story_tabs.join(",")
        : payload.story_tabs,
      filter_label: payload.filter_label,
      sort_label: payload.sort_label,
      empty_title: payload.empty_title,
      empty_cta: payload.empty_cta,
    }),
  });
}

export function updateProfile(payload) {
  return request("/api/admin/profile", { method: "PUT", body: JSON.stringify(payload) });
}

export function createReadingList(payload) {
  return request("/api/admin/reading-lists", { method: "POST", body: JSON.stringify(payload) });
}

export function updateReadingList(id, payload) {
  return request(`/api/admin/reading-lists/${id}`, { method: "PUT", body: JSON.stringify(payload) });
}

export function deleteReadingList(id) {
  return request(`/api/admin/reading-lists/${id}`, { method: "DELETE" });
}

export function createAchievement(payload) {
  const progress = Number(payload.progress ?? 0);
  const total = Number(payload.total ?? 0);
  return request("/api/admin/achievements", {
    method: "POST",
    body: JSON.stringify({
      group_name: payload.group_name ?? "Lifetime Words Published",
      group_order: payload.group_order ?? 2,
      title: payload.title ?? "",
      subtitle: payload.subtitle ?? "",
      progress_label: `${progress}/${total}`,
      badge_value: String(total || 0),
      style: payload.style ?? "ink",
      sort_order: payload.sort_order ?? 999,
    }),
  });
}

export function updateAchievement(id, payload) {
  const progress = Number(payload.progress ?? 0);
  const total = Number(payload.total ?? 0);
  return request(`/api/admin/achievements/${id}`, {
    method: "PUT",
    body: JSON.stringify({
      group_name: payload.group_name,
      group_order: payload.group_order,
      title: payload.title,
      subtitle: payload.subtitle,
      progress_label: `${progress}/${total}`,
      badge_value: String(total || payload.badge_value || 0),
      style: payload.style,
      sort_order: payload.sort_order,
    }),
  });
}

export function deleteAchievement(id) {
  return request(`/api/admin/achievements/${id}`, { method: "DELETE" });
}

export function updateSupportRequest(id, payload) {
  return request(`/api/admin/support-requests/${id}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export { ADMIN_TOKEN_KEY, API_BASE_URL };


export function listAdminUsers() {
  return request("/api/admin/users");
}

export function banUser(id) {
  return request(`/api/admin/users/${id}/ban`, { method: "POST", body: "{}" });
}

export function unbanUser(id) {
  return request(`/api/admin/users/${id}/unban`, { method: "POST", body: "{}" });
}

export function deleteAdminUser(id) {
  return request(`/api/admin/users/${id}`, { method: "DELETE" });
}

export function suspendUser(id, days = 7) {
  return request(`/api/admin/users/${id}/suspend`, {
    method: "POST",
    body: JSON.stringify({ days: Number(days) || 7 }),
  });
}

export function restoreUser(id) {
  return request(`/api/admin/users/${id}/restore`, { method: "POST", body: "{}" });
}

export function setAuthorActive(id, active = true) {
  return request(`/api/admin/users/${id}/author-active`, {
    method: "POST",
    body: JSON.stringify({ active: !!active }),
  });
}

export function unsuspendUser(id) {
  return request(`/api/admin/users/${id}/unsuspend`, { method: "POST", body: "{}" });
}

export function activateUser(id) {
  return request(`/api/admin/users/${id}/activate`, { method: "POST", body: "{}" });
}


export function listAdminTags() {
  return request("/api/admin/tags");
}

export function createAdminTag(payload) {
  return request("/api/admin/tags", { method: "POST", body: JSON.stringify(payload) });
}

export function updateAdminTag(id, payload) {
  return request(`/api/admin/tags/${id}`, { method: "PUT", body: JSON.stringify(payload) });
}

export function deleteAdminTag(id) {
  return request(`/api/admin/tags/${id}`, { method: "DELETE" });
}

export function listStoryReports() {
  return request("/api/admin/reports");
}

