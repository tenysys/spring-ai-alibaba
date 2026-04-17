$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mdPath = Join-Path $baseDir '数据库运行设计.md'
$docxPath = Join-Path $baseDir '数据库运行设计_优化版.docx'
$tempDocxPath = Join-Path $baseDir 'database_runtime_design_tmp.docx'

function Convert-InlineMarkdown {
    param([string]$text)
    if ($null -eq $text) { return '' }
    $t = $text
    $t = $t.Replace([string][char]96, '')
    $t = $t.Replace('**', '')
    $t = $t.Replace('__', '')
    return $t.TrimEnd()
}

$lines = [System.IO.File]::ReadAllLines($mdPath, [System.Text.Encoding]::UTF8)
$word = $null
$doc = $null

try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $doc = $word.Documents.Add()

    $section = $doc.Sections.Item(1)
    $pageSetup = $section.PageSetup
    $pageSetup.TopMargin = $word.CentimetersToPoints(2.54)
    $pageSetup.BottomMargin = $word.CentimetersToPoints(2.54)
    $pageSetup.LeftMargin = $word.CentimetersToPoints(3.18)
    $pageSetup.RightMargin = $word.CentimetersToPoints(3.18)

    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        $trimmed = $line.Trim()

        if ($trimmed -eq '') {
            $doc.Content.InsertAfter("`r") | Out-Null
            $i++
            continue
        }

        if ($trimmed -match '^(#{1,6})\s+(.+)$') {
            $level = $matches[1].Length
            $content = Convert-InlineMarkdown $matches[2]
            $range = $doc.Content
            $range.Collapse(0)
            $range.InsertAfter($content)
            $p = $doc.Paragraphs.Last
            $p.Range.Text = $content
            $p.Range.Style = "标题 $([Math]::Min($level, 3))"
            $p.Alignment = if ($level -eq 1) { 1 } else { 0 }
            $p.LineSpacingRule = 1

            switch ($level) {
                1 {
                    $p.Range.Font.NameFarEast = '黑体'
                    $p.Range.Font.Name = '黑体'
                    $p.Range.Font.Size = 18
                    $p.Range.Font.Bold = 1
                    $p.SpaceBefore = 0
                    $p.SpaceAfter = 18
                }
                2 {
                    $p.Range.Font.NameFarEast = '黑体'
                    $p.Range.Font.Name = '黑体'
                    $p.Range.Font.Size = 16
                    $p.Range.Font.Bold = 1
                    $p.SpaceBefore = 12
                    $p.SpaceAfter = 12
                }
                default {
                    $p.Range.Font.NameFarEast = '黑体'
                    $p.Range.Font.Name = '黑体'
                    $p.Range.Font.Size = 14
                    $p.Range.Font.Bold = 1
                    $p.SpaceBefore = 6
                    $p.SpaceAfter = 6
                }
            }

            $doc.Content.InsertAfter("`r") | Out-Null
            $i++
            continue
        }

        if ($trimmed.StartsWith('|')) {
            $tableLines = @()
            while ($i -lt $lines.Count -and $lines[$i].Trim().StartsWith('|')) {
                $tableLines += $lines[$i].Trim()
                $i++
            }

            if ($tableLines.Count -ge 2) {
                $rows = @()
                foreach ($tLine in $tableLines) {
                    if ($tLine -match '^\|(?:\s*:?[-]+:??\s*\|)+$') { continue }
                    $cells = $tLine.Trim('|').Split('|') | ForEach-Object { Convert-InlineMarkdown $_.Trim() }
                    $rows += ,$cells
                }

                if ($rows.Count -gt 0) {
                    $colCount = ($rows[0]).Count
                    $endRange = $doc.Content
                    $endRange.Collapse(0)
                    $table = $doc.Tables.Add($endRange, $rows.Count, $colCount)
                    $table.Borders.Enable = 1
                    $table.Range.Font.NameFarEast = '宋体'
                    $table.Range.Font.Name = 'Times New Roman'
                    $table.Range.Font.Size = 10.5

                    for ($r = 1; $r -le $rows.Count; $r++) {
                        for ($c = 1; $c -le $colCount; $c++) {
                            $table.Cell($r, $c).Range.Text = $rows[$r - 1][$c - 1]
                            if ($r -eq 1) {
                                $table.Cell($r, $c).Range.Bold = 1
                                $table.Cell($r, $c).Shading.BackgroundPatternColor = 15132390
                            }
                        }
                    }

                    $doc.Content.InsertAfter("`r") | Out-Null
                }
            }

            continue
        }

        $prefix = ''
        $content = $trimmed
        if ($trimmed -match '^[-\*]\s+(.+)$') {
            $prefix = '• '
            $content = $matches[1]
        } elseif ($trimmed -match '^(\d+\.)\s+(.+)$') {
            $prefix = "$($matches[1]) "
            $content = $matches[2]
        }

        $content = $prefix + (Convert-InlineMarkdown $content)
        $range = $doc.Content
        $range.Collapse(0)
        $range.InsertAfter($content)
        $p = $doc.Paragraphs.Last
        $p.Range.Text = $content
        $p.Range.Style = '正文'
        $p.Range.Font.NameFarEast = '宋体'
        $p.Range.Font.Name = 'Times New Roman'
        $p.Range.Font.Size = 12
        $p.Range.Font.Bold = 0
        $p.Alignment = 0
        $p.LeftIndent = 0
        $p.FirstLineIndent = 0
        $p.LineSpacingRule = 1
        $p.SpaceBefore = 0
        $p.SpaceAfter = 6
        $doc.Content.InsertAfter("`r") | Out-Null
        $i++
    }

    if (Test-Path $tempDocxPath) {
        Remove-Item $tempDocxPath -Force
    }

    $doc.SaveAs($tempDocxPath, 16)
    $doc.Close()
    $word.Quit()

    if (Test-Path $docxPath) {
        Remove-Item $docxPath -Force
    }
    Move-Item $tempDocxPath $docxPath -Force
}
finally {
    if ($doc -ne $null) {
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc) | Out-Null
    }
    if ($word -ne $null) {
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
