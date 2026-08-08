"""Generate the one-page OSC 2026 project proposal PDF."""

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.platypus import (
    KeepTogether,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf" / "MedSeal-MBT-project-proposal.pdf"
PURPLE = colors.HexColor("#6F46FF")
INK = colors.HexColor("#18212F")
MUTED = colors.HexColor("#5E6878")
PANEL = colors.HexColor("#F5F3FF")


def section(title: str, body: str, styles: dict[str, ParagraphStyle]):
    return KeepTogether(
        [
            Paragraph(title, styles["section"]),
            Spacer(1, 1.2 * mm),
            Paragraph(body, styles["body"]),
        ]
    )


def build() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    pdfmetrics.registerFont(UnicodeCIDFont("STSong-Light"))
    base = getSampleStyleSheet()
    styles = {
        "title": ParagraphStyle(
            "title",
            parent=base["Title"],
            fontName="STSong-Light",
            fontSize=20,
            leading=24,
            textColor=PURPLE,
            alignment=TA_CENTER,
            spaceAfter=2 * mm,
        ),
        "subtitle": ParagraphStyle(
            "subtitle",
            parent=base["Normal"],
            fontName="STSong-Light",
            fontSize=9.5,
            leading=13,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
        "section": ParagraphStyle(
            "section",
            parent=base["Heading2"],
            fontName="STSong-Light",
            fontSize=11.5,
            leading=14,
            textColor=PURPLE,
            spaceBefore=2.6 * mm,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["BodyText"],
            fontName="STSong-Light",
            fontSize=8.7,
            leading=12.5,
            textColor=INK,
        ),
        "meta": ParagraphStyle(
            "meta",
            parent=base["BodyText"],
            fontName="STSong-Light",
            fontSize=8.3,
            leading=11.2,
            textColor=INK,
        ),
    }
    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        leftMargin=15 * mm,
        rightMargin=15 * mm,
        topMargin=12 * mm,
        bottomMargin=12 * mm,
        title="MedSeal-MBT 项目申报书",
        author="001-Elsa",
        subject="2026 MoonBit 国产基础软件开源大赛项目申报",
    )
    story = [
        Paragraph("MedSeal-MBT 项目申报书", styles["title"]),
        Paragraph(
            "MoonBit DICOM 医学影像元数据清理工具", styles["subtitle"]
        ),
        Spacer(1, 3.2 * mm),
    ]
    meta = [
        ["参赛者", "以官方报名问卷填写为准", "参赛账号", "001-Elsa"],
        ["项目方向", "医学影像格式解析与安全工具", "许可证", "Apache-2.0"],
        ["GitHub", "https://github.com/001-Elsa/MedSeal-MBT", "版本", "0.1.1"],
        ["GitLink", "https://gitlink.org.cn/Hzhhhh/MedSeal-MBT", "后端", "Native"],
        ["Mooncakes", "https://mooncakes.io/docs/001-Elsa/medseal", "项目性质", "原创实现"],
    ]
    table = Table(meta, colWidths=[22 * mm, 74 * mm, 20 * mm, 58 * mm])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), PANEL),
                ("TEXTCOLOR", (0, 0), (-1, -1), INK),
                ("FONTNAME", (0, 0), (-1, -1), "STSong-Light"),
                ("FONTSIZE", (0, 0), (-1, -1), 8.1),
                ("LEADING", (0, 0), (-1, -1), 10.5),
                ("TEXTCOLOR", (0, 0), (0, -1), PURPLE),
                ("TEXTCOLOR", (2, 0), (2, -1), PURPLE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("BOX", (0, 0), (-1, -1), 0.6, colors.HexColor("#D9D2FF")),
                ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#E3DEFF")),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.extend(
        [
            table,
            section(
                "项目简介",
                "MedSeal-MBT 是使用 MoonBit 编写的轻量级 DICOM 医学影像元数据解析、结构校验和基础元数据脱敏工具。项目支持 DICOM Part 10 文件与 Explicit VR Little Endian 传输语法，可读取常见数据元素、基础嵌套 Sequence 和 Pixel Data，并在处理后输出新的 DICOM 文件与不包含原始敏感值的 JSON 审计报告。",
                styles,
            ),
            section(
                "项目方向与适用场景",
                "项目方向属于围绕实际开发需求制作的 MoonBit 开发工具，适用于公开测试数据整理、教学演示、DICOM 文件结构学习、开发联调前的样本清理，以及 MoonBit 在医学影像文件格式解析领域的生态实践。项目避免做医疗诊断、网络服务、PACS、DICOMweb 或像素内容识别，边界清晰、可离线运行。",
                styles,
            ),
            section(
                "核心功能",
                "1. 解析 File Meta、常用文本/整数 VR、定义及常见未定义长度 Sequence。<br/>2. 检测截断、越界长度、非法 VR/UI/文本值、损坏 Sequence 与基础图像元数据问题。<br/>3. 替换或清空患者、机构、医生等直接身份字段，递归处理 Sequence，可选删除 Private Tag。<br/>4. Pixel Data 与 UID 原样保留；JSON 审计只记录 tag、字段名和动作，不记录原始值。<br/>5. 重新计算长度并写入临时文件，解析复检成功后原子替换；提供 inspect、validate、anonymize CLI。",
                styles,
            ),
            section(
                "项目性质与开源合规",
                "本项目为原创 MoonBit 实现，不是对其他成熟开源项目的移植或复制。仓库采用 Apache-2.0 许可证，第三方依赖和样本来源在 THIRD_PARTY.md 与 samples/README.md 中说明；测试样本由项目工具人工生成，不包含真实患者隐私信息。项目已同步公开到 GitHub 与 GitLink，并发布至 mooncakes.io。",
                styles,
            ),
            section(
                "质量与边界",
                "项目核心功能主要由 MoonBit 实现，仓库包含 README、架构说明、更新日志、安全说明、CI、可运行示例和自动化测试。当前版本通过 moon fmt --check、moon check --target all --deny-warn、moon test --target all --deny-warn、moon build --target native 与 GitHub Actions。MedSeal-MBT 只做基础元数据脱敏，不检查 Pixel Data 中烧录的个人信息，不保证完全匿名化，也不宣称医疗法规合规。",
                styles,
            ),
            Spacer(1, 3 * mm),
            Paragraph(
                "联系方式：766903826@qq.com　|　A simple DICOM metadata validator and de-identification tool written in MoonBit.",
                styles["subtitle"],
            ),
        ]
    )
    doc.build(story)
    print(OUTPUT)


if __name__ == "__main__":
    build()
