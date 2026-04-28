import { createTwoFilesPatch } from "diff"
import { html as diff2htmlHtml } from "diff2html"
import "diff2html/bundles/css/diff2html.min.css"

const DiffViewer = {
    mounted() { this.render() },
    updated() { this.render() },

    render() {
        const oldContent = this.el.dataset.oldContent || ""
        const newContent = this.el.dataset.newContent || ""

        if (!oldContent || !newContent) {
            this.el.innerHTML = `<p class="text-sm text-gray-400 italic p-4">No previous version to compare against.</p>`
            return
        }

        const patch = createTwoFilesPatch(
            "Previous version", "Revised version",
            oldContent, newContent,
            "", "", { context: 5 }
        )

        this.el.innerHTML = diff2htmlHtml(patch, {
            drawFileList: false,
            matching: "lines",
            outputFormat: "side-by-side",
        })
    }
}

export default DiffViewer