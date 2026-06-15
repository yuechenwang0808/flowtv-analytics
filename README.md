# 求职自动抓取脚本 · 部署指南

## 文件结构

```
job_scraper/
├── scraper.py
├── requirements.txt
└── .github/
    └── workflows/
        └── scrape.yml
```

---

## 自动运行时间（PST）

| PST | UTC (cron) |
|-----|------------|
| 08:00 | 16:00 |
| 09:00 | 17:00 |
| 12:00 | 20:00 |
| 14:00 | 22:00 |
| 17:00 | 01:00 |
| 20:00 | 04:00 |

每次只抓**过去3小时**内发布的新职位，所以不会重复。

---

## 抓取平台

- ✅ Indeed
- ✅ LinkedIn（公开数据，不需要登录）
- ✅ Google Jobs
- ✅ Glassdoor

> ⚠️ LinkedIn 和 Glassdoor 有反爬虫机制，偶尔可能返回空结果，属正常现象。

---

## 过滤条件

| 条件 | 设置 |
|------|------|
| 搜索关键词 | Data Analyst / Product Analyst / Business Analyst / Analytics Engineer |
| 地点 | San Francisco CA + Remote |
| 排除级别 | Senior, Sr, Staff, Principal, Manager, Director, Lead, VP, Head of, Chief |
| 最低薪资 | $95,000/年（无薪资信息的职位默认保留） |
| 数据时效 | 过去3小时内发布 |

---

## 部署步骤

### 第一步：创建 Google Sheets

1. 新建 Google Sheets，命名为 **`Job Alerts`**（必须一致）
2. 第一行留空，脚本自动写入表头

---

### 第二步：Google Service Account

1. 打开 [Google Cloud Console](https://console.cloud.google.com)
2. 新建项目（随便起名）
3. **APIs & Services → Enable APIs**：
   - 启用 **Google Sheets API**
   - 启用 **Google Drive API**
4. **IAM & Admin → Service Accounts → Create Service Account**
5. 点刚建的账号 → **Keys → Add Key → JSON** → 下载
6. 打开你的 Google Sheets → **Share** → 把 JSON 里的 `client_email` 加为 **Editor**

---

### 第三步：上传到 GitHub

1. 新建 GitHub repo（建议设为 Private）
2. 上传以下文件：
   - `scraper.py`
   - `requirements.txt`
   - `.github/workflows/scrape.yml`

---

### 第四步：设置 Secret

1. GitHub repo → **Settings → Secrets and variables → Actions**
2. **New repository secret**
   - Name: `GOOGLE_CREDENTIALS_JSON`
   - Value: 粘贴 JSON 文件的**完整内容**
3. Save

---

### 第五步：测试

1. GitHub repo → **Actions → Job Scraper → Run workflow**
2. 等 1-2 分钟查看日志
3. 打开 Google Sheets 确认数据写入

---

## Google Sheets 列说明

| 列 | 内容 |
|----|------|
| A | Date Found |
| B | Title |
| C | Company |
| D | Location |
| E | Salary |
| F | Job Type |
| G | Source（indeed/linkedin/google/glassdoor） |
| H | URL |
| I | Description Preview（前200字） |

---

## 常见问题

**Q：Sheets 没有数据？**
检查 Service Account 的 `client_email` 是否加到了 Sheets 的 Editor 权限。

**Q：LinkedIn/Glassdoor 返回空结果？**
这两个平台有反爬虫，偶尔会失败。Indeed 和 Google Jobs 更稳定。

**Q：想修改搜索关键词或薪资门槛？**
编辑 `scraper.py` 顶部的配置区域，push 到 GitHub 即生效。

**Q：想增加运行频率？**
在 `scrape.yml` 里加更多 cron 行即可。
