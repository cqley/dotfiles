var from = 0

function mark(load) {
	var m = location.hash.match(/^#l(\d+)(?:-(\d+))?$/)
	document.querySelectorAll(".ln a.on").forEach(function (x) { x.classList.remove("on") })
	if (!m) return
	var s = +m[1], e = +(m[2] || m[1])
	if (!m[2] || !from) from = s
	for (var i = s; i <= e; i++) {
		var x = document.getElementById("l" + i)
		if (x) x.classList.add("on")
	}
	if (load && m[2] && document.getElementById("l" + s)) document.getElementById("l" + s).scrollIntoView({ block: "center" })
}

document.addEventListener("click", function (ev) {
	var x = ev.target.closest(".ln a")
	if (!x || !ev.shiftKey || !from) return
	ev.preventDefault()
	var n = +x.id.slice(1)
	location.hash = "l" + Math.min(from, n) + "-" + Math.max(from, n)
})

addEventListener("hashchange", function () { mark() })
mark(1)

var find = document.getElementById("find")

if (find) {
	var files = null, tree = document.querySelector(".tree"), hits = document.createElement("table")
	hits.className = "tree"
	find.hidden = false
	hits.hidden = true
	tree.after(hits)

	var load = function () {
		if (files) return
		files = []
		fetch(find.dataset.files).then(function (r) {
			if (!r.ok) throw r.status
			return r.text()
		}).then(function (t) {
			files = t.split("\n").filter(Boolean)
			show()
		}).catch(function () { files = null })
	}

	var show = function () {
		var q = find.value.toLowerCase().split(" ").filter(Boolean)
		tree.hidden = q.length > 0
		hits.hidden = !q.length
		if (!q.length || !files) return
		var m = files.filter(function (f) {
			f = f.toLowerCase()
			return q.every(function (w) { return f.indexOf(w) >= 0 })
		}).slice(0, 100)
		hits.replaceChildren()
		m.forEach(function (f) {
			var a = document.createElement("a")
			a.href = find.dataset.base + f.split("/").map(encodeURIComponent).join("/")
			a.textContent = f
			hits.insertRow().insertCell().append(a)
		})
		if (!m.length) hits.insertRow().insertCell().textContent = "nothing"
	}

	find.addEventListener("focus", load)
	find.addEventListener("input", show)
	find.addEventListener("keydown", function (ev) {
		var a = hits.querySelector("a")
		if (ev.key == "Enter" && a && !hits.hidden) location = a.href
		if (ev.key == "Escape") {
			find.value = ""
			show()
			find.blur()
		}
	})
	document.addEventListener("keydown", function (ev) {
		if (ev.key == "/" && document.activeElement != find) {
			ev.preventDefault()
			find.focus()
		}
	})
}
