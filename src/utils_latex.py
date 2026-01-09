\
from __future__ import annotations
from pathlib import Path
from typing import Optional, Sequence
import pandas as pd

def _default_colfmt(ncols: int) -> str:
    # @{} removes extra horizontal padding at the edges (nice for booktabs tables)
    return "@{}" + ("l" * ncols) + "@{}"

def write_three_line_table(
    df: pd.DataFrame,
    tex_path: Path | str,
    caption: Optional[str] = None,
    label: Optional[str] = None,
    notes: Optional[Sequence[str]] = None,
    float_format: str = "{:.3f}",
    index: bool = False,
    colfmt: Optional[str] = None,
    fontsize: str = r"\small",
) -> None:
    """
    Write an academic 'three-line table' LaTeX file using booktabs.
    The output is a standalone table environment (no document preamble).
    """
    tex_path = Path(tex_path)
    tex_path.parent.mkdir(parents=True, exist_ok=True)

    df2 = df.copy()
    # Format floats as strings for stable LaTeX output
    for c in df2.columns:
        if pd.api.types.is_float_dtype(df2[c]) or pd.api.types.is_integer_dtype(df2[c]):
            # keep ints as ints unless NaN
            df2[c] = df2[c].map(lambda x: "" if pd.isna(x) else float_format.format(float(x)))

    if colfmt is None:
        colfmt = _default_colfmt(len(df2.columns) + (1 if index else 0))

    core = df2.to_latex(
        index=index,
        escape=False,
        caption=None,
        label=None,
        column_format=colfmt,
    )

    # Insert \centering and optional threeparttable notes
    lines = []
    lines.append(r"\begin{table}[!htbp]")
    lines.append(r"\centering")
    if fontsize:
        lines.append(fontsize)
    if caption:
        lines.append(rf"\caption{{{caption}}}")
    if label:
        lines.append(rf"\label{{{label}}}")

    if notes:
        lines.append(r"\begin{threeparttable}")
        lines.append(core.strip())
        lines.append(r"\begin{tablenotes}[flushleft]")
        lines.append(r"\footnotesize")
        for n in notes:
            lines.append(rf"\item {n}")
        lines.append(r"\end{tablenotes}")
        lines.append(r"\end{threeparttable}")
    else:
        lines.append(core.strip())

    lines.append(r"\end{table}")
    tex_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

def write_figure_wrapper(
    image_rel_path: str,
    tex_path: Path | str,
    caption: str,
    label: str,
    width: str = r"0.9\linewidth",
) -> None:
    tex_path = Path(tex_path)
    tex_path.parent.mkdir(parents=True, exist_ok=True)
    content = "\n".join([
        r"\begin{figure}[!htbp]",
        r"\centering",
        rf"\includegraphics[width={width}]{{{image_rel_path}}}",
        rf"\caption{{{caption}}}",
        rf"\label{{{label}}}",
        r"\end{figure}",
        ""
    ])
    tex_path.write_text(content, encoding="utf-8")
