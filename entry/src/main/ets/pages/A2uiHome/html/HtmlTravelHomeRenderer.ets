import { HtmlHomeDocument } from './HtmlHomeTypes';
import { personaAvatarDataUri } from './PersonaAvatarDataUri';

type HtmlTravelTextValue = Object | string | number | boolean | null | undefined;

interface HtmlTravelHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
  personaAvatarDataUri?: string;
}

const TRAVEL_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f5f2ee;
  --void: var(--paper);
  --panel: rgba(255, 255, 255, 0.88);
  --panel-strong: #ffffff;
  --ink: #211b17;
  --ink-soft: #493f38;
  --muted: #7a6e64;
  --line: rgba(33, 27, 23, 0.12);
  --accent: #995f4c;
  --accent-soft: rgba(153, 95, 76, 0.13);
  --chrome: #8a7d70;
  --rail: #16875b;
  --air: #2f79b7;
  --signal: #d8492f;
  --danger: #b04a42;
  --danger-soft: #f6e2df;
  --other: #815f3e;
  --shadow: 0 10px 28px rgba(44, 34, 26, 0.08);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background: transparent;
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled { cursor: default; opacity: 0.52; }
.itinerary-shell {
  width: min(100%, 820px);
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(92px + env(safe-area-inset-bottom, 0px));
  overflow: hidden;
}
.route-hero {
  position: relative;
  min-height: 360px;
  padding: 22px 16px 20px;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  isolation: isolate;
}
.route-hero::before {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -2;
  background:
    linear-gradient(180deg, rgba(248, 242, 232, 0.16) 0%, rgba(248, 242, 232, 0.34) 44%, rgba(248, 242, 232, 0.96) 100%),
    linear-gradient(135deg, #f8f2e8, #fffaf1);
  background-size: cover;
  background-position: center;
  transform: scale(1.02);
}
.route-hero::after {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -1;
  background:
    repeating-linear-gradient(90deg, rgba(23, 18, 13, 0.045) 0 1px, transparent 1px 42px),
    repeating-linear-gradient(0deg, rgba(23, 18, 13, 0.035) 0 1px, transparent 1px 38px);
  mask-image: linear-gradient(180deg, rgba(0,0,0,0.82), transparent 72%);
}
.route-kicker {
  width: fit-content;
  max-width: 100%;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  border: 1px solid rgba(23, 18, 13, 0.14);
  border-radius: 999px;
  padding: 8px 11px;
  background: rgba(255, 250, 241, 0.72);
  color: var(--ink);
  font-size: 12px;
  font-weight: 820;
  line-height: 1;
  backdrop-filter: blur(18px);
}
.route-kicker::before {
  content: "";
  width: 14px;
  height: 14px;
  flex: 0 0 auto;
  background-image: url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KICA8cGF0aCBkPSJNMTIuOTg2MyAyMS42NTUzQzExLjM3NSAyMS42NTUzIDEwLjAwMzkgMjEuMjI0NiA4Ljg3MzA1IDIwLjM2MzNDNy43NDgwNSAxOS41MDIgNi44ODA4NiAxOC4yMjQ2IDYuMjcxNDggMTYuNTMxMkw0LjY5ODI0IDEyLjEzNjdDNC42NDU1MSAxMS45Nzg1IDQuNjA0NDkgMTEuODExNSA0LjU3NTIgMTEuNjM1N0M0LjU0NTkgMTEuNDYgNC41MzEyNSAxMS4yOTg4IDQuNTMxMjUgMTEuMTUyM0M0LjUzMTI1IDEwLjYzMDkgNC43MDQxIDEwLjIyMzYgNS4wNDk4IDkuOTMwNjZDNS4zOTU1MSA5LjYzNzcgNS44MDg1OSA5LjQ5MTIxIDYuMjg5MDYgOS40OTEyMUM2LjYwNTQ3IDkuNDkxMjEgNi44OTI1OCA5LjU3NjE3IDcuMTUwMzkgOS43NDYwOUM3LjQwODIgOS45MTYwMiA3LjYxNjIxIDEwLjE2OCA3Ljc3NDQxIDEwLjUwMkw4LjI2NjYgMTEuNjYyMUM4LjI4NDE4IDExLjcwMzEgOC4zMDc2MiAxMS43MjM2IDguMzM2OTEgMTEuNzIzNkM4LjM3NzkzIDExLjcyMzYgOC4zOTg0NCAxMS42OTQzIDguMzk4NDQgMTEuNjM1N1Y0LjY2NjAyQzguMzk4NDQgNC4wNjI1IDguNTgzMDEgMy41NzkxIDguOTUyMTUgMy4yMTU4MkM5LjMyMTI5IDIuODQ2NjggOS43OTI5NyAyLjY2MjExIDEwLjM2NzIgMi42NjIxMUMxMC45MzU1IDIuNjYyMTEgMTEuMzk4NCAyLjg0NjY4IDExLjc1NTkgMy4yMTU4MkMxMi4xMTkxIDMuNTc5MSAxMi4zMDA4IDQuMDYyNSAxMi4zMDA4IDQuNjY2MDJWNy4zMjAzMUMxMi40NzA3IDcuMjczNDQgMTIuNjQ2NSA3LjI1IDEyLjgyODEgNy4yNUMxMy4yMTQ4IDcuMjUgMTMuNTQ4OCA3LjM1MjU0IDEzLjgzMDEgNy41NTc2MkMxNC4xMTcyIDcuNzU2ODQgMTQuMzI1MiA4LjAzODA5IDE0LjQ1NDEgOC40MDEzN0MxNC42OTQzIDguMzI1MiAxNC45Mzc1IDguMjg3MTEgMTUuMTgzNiA4LjI4NzExQzE1LjU2NDUgOC4yODcxMSAxNS44OTI2IDguMzgwODYgMTYuMTY4IDguNTY4MzZDMTYuNDQzNCA4Ljc1NTg2IDE2LjYzNjcgOS4wMTM2NyAxNi43NDggOS4zNDE4QzE3LjYwMzUgOS4zNTkzOCAxOC4yNjg2IDkuNjY0MDYgMTguNzQzMiAxMC4yNTU5QzE5LjIyMzYgMTAuODQ3NyAxOS40NjM5IDExLjY2MjEgMTkuNDYzOSAxMi42OTkyVjE0LjgwODZDMTkuNDYzOSAxNi4yMzgzIDE5LjE5NzMgMTcuNDYyOSAxOC42NjQxIDE4LjQ4MjRDMTguMTMwOSAxOS41MDIgMTcuMzc3OSAyMC4yODQyIDE2LjQwNTMgMjAuODI5MUMxNS40Mzg1IDIxLjM3OTkgMTQuMjk4OCAyMS42NTUzIDEyLjk4NjMgMjEuNjU1M1pNMTMuMDMwMyAyMC4xNjExQzE0LjA3MzIgMjAuMTYxMSAxNC45Njk3IDE5Ljk0NDMgMTUuNzE5NyAxOS41MTA3QzE2LjQ2OTcgMTkuMDgzIDE3LjA0MzkgMTguNDU5IDE3LjQ0MjQgMTcuNjM4N0MxNy44NDY3IDE2LjgxODQgMTguMDQ4OCAxNS44MjUyIDE4LjA0ODggMTQuNjU5MlYxMi43NzgzQzE4LjA0ODggMTIuMTU3MiAxNy45NTIxIDExLjY3OTcgMTcuNzU4OCAxMS4zNDU3QzE3LjU2NTQgMTEuMDA1OSAxNy4yOSAxMC44MzU5IDE2LjkzMjYgMTAuODM1OVYxMS43MzI0QzE2LjkzMjYgMTEuOTE0MSAxNi44NjgyIDEyLjA2MzUgMTYuNzM5MyAxMi4xODA3QzE2LjYxNjIgMTIuMjk3OSAxNi40NzI3IDEyLjM1NjQgMTYuMzA4NiAxMi4zNTY0QzE2LjEzMjggMTIuMzU2NCAxNS45Nzc1IDEyLjI5NzkgMTUuODQyOCAxMi4xODA3QzE1LjcxMzkgMTIuMDYzNSAxNS42NDk0IDExLjkxNDEgMTUuNjQ5NCAxMS43MzI0VjEwLjM0MzhDMTUuNjQ5NCAxMC4xMzg3IDE1LjU5MzggOS45Nzc1NCAxNS40ODI0IDkuODYwMzVDMTUuMzc3IDkuNzQzMTYgMTUuMjI0NiA5LjY4NDU3IDE1LjAyNTQgOS42ODQ1N0MxNC44NjEzIDkuNjg0NTcgMTQuNzA2MSA5LjcxNjggMTQuNTU5NiA5Ljc4MTI1VjExLjM4MDlDMTQuNTU5NiAxMS41Njg0IDE0LjQ5NTEgMTEuNzIwNyAxNC4zNjYyIDExLjgzNzlDMTQuMjQzMiAxMS45NDkyIDE0LjA5NjcgMTIuMDA0OSAxMy45MjY4IDEyLjAwNDlDMTMuNzU2OCAxMi4wMDQ5IDEzLjYwNzQgMTEuOTQ5MiAxMy40Nzg1IDExLjgzNzlDMTMuMzQ5NiAxMS43MjA3IDEzLjI4NTIgMTEuNTY4NCAxMy4yODUyIDExLjM4MDlWOS4zMDY2NEMxMy4yODUyIDkuMTAxNTYgMTMuMjI2NiA4Ljk0MDQzIDEzLjEwOTQgOC44MjMyNEMxMi45OTggOC43MDYwNSAxMi44NDg2IDguNjQ3NDYgMTIuNjYxMSA4LjY0NzQ2QzEyLjQ5NzEgOC42NDc0NiAxMi4zMzg5IDguNjc5NjkgMTIuMTg2NSA4Ljc0NDE0VjExLjAyOTNDMTIuMTg2NSAxMS4yMDUxIDEyLjEyMjEgMTEuMzU0NSAxMS45OTMyIDExLjQ3NzVDMTEuODcwMSAxMS42MDA2IDExLjcyMDcgMTEuNjYyMSAxMS41NDQ5IDExLjY2MjFDMTEuMzY5MSAxMS42NjIxIDExLjIxNjggMTEuNjAwNiAxMS4wODc5IDExLjQ3NzVDMTAuOTY0OCAxMS4zNTQ1IDEwLjkwMzMgMTEuMjA1MSAxMC45MDMzIDExLjAyOTNWNC41NzgxMkMxMC45MDMzIDQuNDA4MiAxMC44NTM1IDQuMjczNDQgMTAuNzUzOSA0LjE3MzgzQzEwLjY1NDMgNC4wNjgzNiAxMC41MjI1IDQuMDE1NjIgMTAuMzU4NCA0LjAxNTYyQzEwLjE5NDMgNC4wMTU2MiAxMC4wNTk2IDQuMDY4MzYgOS45NTQxIDQuMTczODNDOS44NTQ0OSA0LjI3MzQ0IDkuODA0NjkgNC40MDgyIDkuODA0NjkgNC41NzgxMkw5Ljc5NTkgMTMuNzYyN0M5Ljc5NTkgMTMuOTkxMiA5LjcyNTU5IDE0LjE3ODcgOS41ODQ5NiAxNC4zMjUyQzkuNDUwMiAxNC40NzE3IDkuMjgwMjcgMTQuNTQ0OSA5LjA3NTIgMTQuNTQ0OUM4LjkwNTI3IDE0LjU0NDkgOC43NDcwNyAxNC41MDEgOC42MDA1OSAxNC40MTMxQzguNDU5OTYgMTQuMzI1MiA4LjMzOTg0IDE0LjE2NyA4LjI0MDIzIDEzLjkzODVMNi45ODM0IDExLjI0OUM2Ljg3MjA3IDEwLjk3MzYgNi42OTYyOSAxMC44MzU5IDYuNDU2MDUgMTAuODM1OUM2LjI5Nzg1IDEwLjgzNTkgNi4xNzE4OCAxMC44ODU3IDYuMDc4MTIgMTAuOTg1NEM1Ljk5MDIzIDExLjA3OTEgNS45NDYyOSAxMS4xOTM0IDUuOTQ2MjkgMTEuMzI4MUM1Ljk0NjI5IDExLjQ0NTMgNS45NjY4IDExLjU2NTQgNi4wMDc4MSAxMS42ODg1TDcuNjE2MjEgMTYuMDM5MUM4LjE2MTEzIDE3LjUwOTggOC44ODc3IDE4LjU2NDUgOS43OTU5IDE5LjIwMzFDMTAuNzEgMTkuODQxOCAxMS43ODgxIDIwLjE2MTEgMTMuMDMwMyAyMC4xNjExWiIgZmlsbD0iYmxhY2siLz4KPC9zdmc+Cg==");
  background-size: contain;
  background-repeat: no-repeat;
  background-position: center;
  opacity: 0.82;
}
.route-hero h1 {
  margin: 15px 0 10px;
  max-width: 9.2em;
  overflow-wrap: anywhere;
  font-family: Georgia, "Times New Roman", "Songti SC", serif;
  font-size: 43px;
  line-height: 0.96;
  font-weight: 760;
}
.route-hero p {
  margin: 0;
  max-width: 30em;
  width: fit-content;
  overflow-wrap: anywhere;
  border: 1px solid rgba(23, 18, 13, 0.1);
  border-radius: 18px;
  padding: 8px 10px;
  background: rgba(255, 250, 241, 0.74);
  color: rgba(23, 18, 13, 0.82);
  font-size: 14px;
  font-weight: 650;
  line-height: 1.55;
  backdrop-filter: blur(14px);
}
.persona-banner {
  display: flex;
  align-items: center;
  gap: 10px;
  width: fit-content;
  max-width: 100%;
  margin-top: 14px;
  border: 1px solid rgba(23, 18, 13, 0.14);
  border-radius: 18px;
  padding: 10px 12px;
  background: rgba(255, 250, 241, 0.78);
  color: var(--ink);
  backdrop-filter: blur(18px);
}
.persona-avatar {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 14px;
  background: rgba(255, 250, 241, 0.92);
  color: var(--air);
  font-size: 15px;
  font-weight: 840;
}
.persona-avatar img {
  width: 30px;
  height: 30px;
  object-fit: contain;
}
.persona-copy {
  min-width: 0;
  flex: 1 1 auto;
}
.persona-title {
  font-size: 14px;
  font-weight: 840;
  line-height: 1.25;
}
.persona-subtitle {
  margin-top: 4px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.4;
  overflow-wrap: anywhere;
}
.route-map {
  margin-top: 14px;
  border: 1px solid var(--line);
  border-radius: 22px;
  padding: 12px;
  background: rgba(255, 250, 241, 0.82);
  box-shadow: var(--shadow);
  backdrop-filter: blur(20px);
}
.route-cities {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  gap: 10px;
  align-items: center;
}
.route-city {
  min-width: 0;
  border-radius: 16px;
  padding: 11px 12px;
  background: rgba(23, 18, 13, 0.06);
}
.route-city b {
  display: block;
  overflow-wrap: anywhere;
  font-size: 18px;
  line-height: 1.1;
}
.route-city span {
  display: block;
  margin-top: 5px;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.2;
}
.route-mid {
  position: relative;
  width: 78px;
  height: 42px;
}
.route-mid::before {
  content: "";
  position: absolute;
  left: 12px;
  right: 12px;
  top: 23px;
  height: 7px;
  background: linear-gradient(90deg, var(--rail), var(--air), var(--signal));
  clip-path: polygon(0 38%, calc(100% - 8px) 38%, calc(100% - 8px) 0, 100% 50%, calc(100% - 8px) 100%, calc(100% - 8px) 62%, 0 62%);
}
.route-mid::after {
  content: "";
  position: absolute;
  left: 50%;
  top: 12px;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  border: 1px solid transparent;
  background-color: transparent;
  background-image: url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAwXzQ1ODRfMzE0KSI+CjxwYXRoIGQ9Ik0xNS44MTI1IDE5LjM5NTRDMTUuOTczNSAxOS43OTQgMTYuNDg5MSAxOS44OTg4IDE2Ljc5MzEgMTkuNTk0OUwxNy40NTg2IDE4LjkyOTRDMTcuNzM1OSAxOC42NTIgMTcuODYwMiAxOC4yNTY2IDE3Ljc5MTQgMTcuODcwNEwxNi40MDk5IDEwLjExNDFMMjAuMzE4NCA2LjQ1MzI1QzIxLjU0NTkgNS4yNzgzMyAyMS4yNTM0IDMuNzQzNzcgMjAuNzU1NyAzLjI0NjAxQzIwLjI1NzkgMi43NDgyNSAxOC42NjIyIDIuNTMxOTUgMTcuNTUwNiAzLjY4NTVMMTMuODk1MSA3LjU5OTMyTDYuMTMxNjggNi4yMTA3NkM1Ljc0NTI1IDYuMTQxNjUgNS4zNDk0NSA2LjI2NTkxIDUuMDcxODcgNi41NDM0OUw0LjQwNjM3IDcuMjA4OThDNC4xMDI1MyA3LjUxMjgzIDQuMjA3MjIgOC4wMjgyMSA0LjYwNTU0IDguMTg5NDJMMTAuNzk4NSAxMC42OTU5TDcuMjM1MjMgMTQuNzAyMUw0Ljg1MTI3IDE0LjAxNzdDNC42NDE1NyAxMy45NTc1IDQuNDE1NzIgMTQuMDE1OSA0LjI2MTQ1IDE0LjE3MDFMMy4zMDY3OSAxNS4xMjQ4QzMuMTY1MjQgMTUuMjY2MyAzLjE5OTQgMTUuNTA0MiAzLjM3NTA5IDE1LjYwMDJMNi42MjY4MSAxNy4zNzY4TDguNDAxNTEgMjAuNjI2NUM4LjQ5NzQ3IDIwLjgwMjIgOC43MzUzNiAyMC44MzY0IDguODc2OTMgMjAuNjk0OEw5LjgzMTUzIDE5Ljc0MDJDOS45ODU4IDE5LjU4NTkgMTAuMDQ0MiAxOS4zNjAxIDkuOTgzOTcgMTkuMTUwNEw5LjI5OTYxIDE2Ljc2NjRMMTMuMzEzMyAxMy4yMTA3TDE1LjgxMjUgMTkuMzk1NFoiIHN0cm9rZT0iYmxhY2siIHN0cm9rZS13aWR0aD0iMS41Ii8+CjwvZz4KPGRlZnM+CjxjbGlwUGF0aCBpZD0iY2xpcDBfNDU4NF8zMTQiPgo8cmVjdCB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIGZpbGw9IndoaXRlIi8+CjwvY2xpcFBhdGg+CjwvZGVmcz4KPC9zdmc+Cg==");
  background-repeat: no-repeat;
  background-size: 17px 17px;
  background-position: center;
  box-shadow: none;
  transform: translate(-50%, -50%);
}
.route-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  margin-top: 12px;
}
.route-stat {
  min-width: 0;
  border-radius: 14px;
  padding: 9px;
  background: rgba(23, 18, 13, 0.05);
}
.route-stat span {
  display: block;
  color: var(--muted);
  font-size: 10px;
  line-height: 1;
}
.route-stat b {
  display: block;
  margin-top: 6px;
  overflow-wrap: anywhere;
  font-size: 14px;
  line-height: 1.15;
}
.travel-controls {
  position: sticky;
  top: 0;
  z-index: 8;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 12px 14px;
  background: rgba(248, 242, 232, 0.92);
  border-bottom: 1px solid rgba(23, 18, 13, 0.06);
  backdrop-filter: blur(18px);
  scrollbar-width: none;
}
.travel-controls::-webkit-scrollbar { display: none; }
.travel-control {
  flex: 0 0 auto;
  border: 1px solid var(--line);
  border-radius: 999px;
  min-height: 38px;
  padding: 10px 13px;
  background: rgba(255, 250, 241, 0.92);
  color: var(--ink);
  font-size: 12px;
  font-weight: 760;
  line-height: 1;
  white-space: nowrap;
}
.travel-control.active {
  border-color: var(--ink);
  background: var(--ink);
  color: var(--void);
}
.journey-board {
  display: grid;
  gap: 10px;
  padding: 10px 14px 20px;
}
.travel-evidence {
  margin: 12px 14px 0;
  border: 1px solid var(--line);
  border-radius: 18px;
  padding: 12px;
  background: rgba(255, 250, 241, 0.88);
}
.travel-evidence h2 {
  margin: 0;
  font-size: 15px;
  line-height: 1.3;
}
.travel-evidence p {
  margin: 7px 0 0;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.5;
}
.travel-evidence-grid {
  display: grid;
  gap: 7px;
  margin-top: 10px;
}
.travel-evidence-row {
  display: grid;
  grid-template-columns: minmax(88px, auto) minmax(0, 1fr);
  gap: 10px;
  font-size: 11px;
  line-height: 1.45;
}
.travel-evidence-row b { color: var(--muted); }
.travel-evidence-row span { overflow-wrap: anywhere; }
.journey-empty {
  border: 1px dashed rgba(23, 18, 13, 0.18);
  border-radius: 20px;
  padding: 18px;
  background: var(--panel);
  color: var(--muted);
  line-height: 1.55;
}
.journey-card {
  --source: var(--other);
  position: relative;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: 22px;
  padding: 12px;
  background:
    linear-gradient(135deg, rgba(255, 250, 241, 0.98), rgba(255, 247, 231, 0.9)),
    var(--panel);
  box-shadow: 0 12px 30px rgba(37, 24, 13, 0.09);
}
.journey-card[data-source="train"] { --source: var(--rail); }
.journey-card[data-source="flight"] { --source: var(--air); }
.journey-card[data-source="food"] { --source: var(--signal); }
.journey-card.selected {
  border-color: var(--source);
  box-shadow: 0 0 0 2px var(--source), var(--shadow);
}
.journey-card.calendar-conflict {
  border-color: var(--danger);
  box-shadow: 0 0 0 1px var(--danger), var(--shadow);
}
.journey-card::before {
  content: "";
  position: absolute;
  inset: 0 0 auto;
  height: 5px;
  background: linear-gradient(90deg, var(--source), rgba(23, 18, 13, 0.08));
}
.journey-card::after {
  content: "";
  position: absolute;
  right: -48px;
  top: -48px;
  width: 132px;
  height: 132px;
  border-radius: 50%;
  border: 1px solid rgba(23, 18, 13, 0.08);
  background: radial-gradient(circle, rgba(23, 18, 13, 0.06), transparent 68%);
  opacity: 0.72;
  pointer-events: none;
}
.journey-top {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 12px;
  align-items: start;
}
.journey-tag {
  width: fit-content;
  max-width: 100%;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  border-radius: 999px;
  padding: 6px 9px;
  border: 1px solid var(--source);
  background: rgba(255, 250, 241, 0.9);
  color: var(--source);
  font-size: 10px;
  font-weight: 840;
  line-height: 1;
  overflow-wrap: anywhere;
}
.journey-tag::before {
  content: "";
  display: none;
  width: 13px;
  height: 13px;
  flex: 0 0 auto;
  background-size: contain;
  background-repeat: no-repeat;
  background-position: center;
  opacity: 0.82;
}
.journey-tag.train::before {
  display: block;
  background-image: url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAwXzQ1ODRfMzE2KSI+CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNMTIuMDAyOSAwLjYxNDI1OEMxMi44MjkxIDAuNjE0MjU4IDEzLjU4NzkgMC42Mzc2OTUgMTQuMjc5MyAwLjY4NDU3QzE0Ljk3MDcgMC43MjU1ODUgMTUuNDgzNCAwLjc2MzY3MiAxNS44MTc0IDAuNzk4ODI4QzE2LjQ3OTUgMC44ODY3MjMgMTcuMDY1NCAxLjA4MzAyIDE3LjU3NTIgMS4zODc3QzE4LjA5MDcgMS42ODY1MSAxOC41MTg2IDIuMDk2NzUgMTguODU4NCAyLjYxODE2QzE5LjIwNCAzLjEzMzcyIDE5LjQ1NjEgMy43NDYyNSAxOS42MTQzIDQuNDU1MDhDMTkuNzM3MyA0Ljk3MDU5IDE5Ljg0NTcgNS41NDgwNCAxOS45Mzk1IDYuMTg2NTJDMjAuMDM5IDYuODI1MDYgMjAuMTE1MiA3LjUxMzg2IDIwLjE2OCA4LjI1MTk1QzIwLjIyNjUgOC45ODQyMyAyMC4yNTU5IDkuNzUyMTMgMjAuMjU1OSAxMC41NTQ3VjE2LjI1QzIwLjI1NTggMTYuOTQ3MSAyMC4xMTgxIDE3LjU2MjYgMTkuODQyOCAxOC4wOTU3QzE5LjU3MzIgMTguNjIyOSAxOS4xODA1IDE5LjAzMzMgMTguNjY1IDE5LjMyNjJDMTguMTk2MyAxOS41OTU1IDE3LjY0MyAxOS43MzgxIDE3LjAwNTkgMTkuNzU5OEwxOC43MDAyIDIyLjQ5MDJDMTguNzg3OSAyMi42MzA3IDE4LjgyMzIgMjIuNzY4NyAxOC44MDU3IDIyLjkwMzNDMTguNzg4IDIzLjAzNzkgMTguNzI5NCAyMy4xNTI1IDE4LjYyOTkgMjMuMjQ2MUMxOC41MzYyIDIzLjMzOTcgMTguNDEgMjMuMzg2NyAxOC4yNTIgMjMuMzg2N0gxNy43NDIyQzE3LjQ5MDQgMjMuMzg2NyAxNy4yOTM5IDIzLjI3MjIgMTcuMTUzMyAyMy4wNDM5TDE2LjY2MTEgMjIuMjUyOUg3LjMwNzYyTDYuODE3MzggMjMuMDQzOUM2LjY3Njc3IDIzLjI3MjIgNi40ODAzNCAyMy4zODY3IDYuMjI4NTIgMjMuMzg2N0g1LjY4MzU5QzUuNTE5NjcgMjMuMzg2NyA1LjM5MDYgMjMuMzM5NyA1LjI5Njg4IDIzLjI0NjFDNS4yMDMyNCAyMy4xNTgzIDUuMTQ3NTMgMjMuMDQ2NyA1LjEyOTg4IDIyLjkxMjFDNS4xMTgxNyAyMi43ODMzIDUuMTUzNDggMjIuNjUxMiA1LjIzNTM1IDIyLjUxNjZMNi45NTMxMiAxOS43NTg4QzYuMzMwMjIgMTkuNzMxOSA1Ljc4OTY3IDE5LjU4OTEgNS4zMzIwMyAxOS4zMjYyQzQuODIyMzkgMTkuMDMzMyA0LjQyOTY4IDE4LjYyMjkgNC4xNTQzIDE4LjA5NTdDMy44ODQ4MyAxNy41NjI2IDMuNzUwMDYgMTYuOTQ3MSAzLjc1IDE2LjI1VjEwLjQ5MzJDMy43NSA5LjY5MDYxIDMuNzc2MzkgOC45Mjg1NyAzLjgyOTEgOC4yMDgwMUMzLjg4NzY4IDcuNDgxNjMgMy45NjM5IDYuODA0NTUgNC4wNTc2MiA2LjE3NzczQzQuMTU3MiA1LjU0NTExIDQuMjY4NiA0Ljk3MDU4IDQuMzkxNiA0LjQ1NTA4QzQuNTQ5NzcgMy43NDYyNSA0Ljc5ODk0IDMuMTMzNzIgNS4xMzg2NyAyLjYxODE2QzUuNDc4NDcgMi4wOTY3NSA1LjkwMzQxIDEuNjg2NTEgNi40MTMwOSAxLjM4NzdDNi45Mjg2OSAxLjA4MzAyIDcuNTIwNTMgMC44ODY3MjMgOC4xODg0OCAwLjc5ODgyOEM4LjUxNjYgMC43NjM2NzIgOS4wMDg4IDAuNzI1NTg1IDkuNjY1MDQgMC42ODQ1N0MxMC4zMjEzIDAuNjM3Njk1IDExLjEwMDYgMC42MTQyNTggMTIuMDAyOSAwLjYxNDI1OFpNOC44NTA1OSAxOS43NjU2TDguMjEyODkgMjAuNzkzOUgxNS43NTI5TDE1LjExMzMgMTkuNzY1Nkg4Ljg1MDU5Wk0xMi4wMDI5IDIuMDIwNTFDMTEuMTQxNiAyLjAyMDUxIDEwLjQwMDQgMi4wNDEwMiA5Ljc3OTMgMi4wODIwM0M5LjE1ODIyIDIuMTE3MTkgOC42ODY1MiAyLjE1MjM0IDguMzY0MjYgMi4xODc1QzcuOTA3MjUgMi4yNDAyNCA3LjUwMjkyIDIuMzY5MTUgNy4xNTEzNyAyLjU3NDIyQzYuODA1NzYgMi43NzkyOSA2LjUxNTU4IDMuMDYwNjIgNi4yODEyNSAzLjQxNzk3QzYuMDQ2OTkgMy43Njk0NyA1Ljg3Mzk5IDQuMTk3NDMgNS43NjI3IDQuNzAxMTdDNS42NzQ4NSA1LjA3NjA0IDUuNTkyNzQgNS40Nzc3MiA1LjUxNjYgNS45MDUyN0M1LjQ0NjMyIDYuMzMyODcgNS4zODE4MSA2Ljc5MDIyIDUuMzIzMjQgNy4yNzYzN0M1LjI3MDUzIDcuNzU2NjkgNS4yMjY1NSA4LjI2Njc4IDUuMTkxNDEgOC44MDU2NkM1LjE2MjEzIDkuMzQ0NTggNS4xNDc0NiA5LjkwNzQgNS4xNDc0NiAxMC40OTMyVjE2LjE3OTdDNS4xNDc1MiAxNi42MDcyIDUuMjI2NjIgMTYuOTg1NSA1LjM4NDc3IDE3LjMxMzVDNS41NDg4MyAxNy42NDE0IDUuNzk1MDUgMTcuODk5NSA2LjEyMzA1IDE4LjA4NjlDNi40NTcgMTguMjY4NSA2Ljg3OTAxIDE4LjM1OTQgNy4zODg2NyAxOC4zNTk0SDE2LjYwODRDMTcuMTE4MSAxOC4zNTk0IDE3LjU0MDEgMTguMjY4NSAxNy44NzQgMTguMDg2OUMxOC4yMDc5IDE3Ljg5OTUgMTguNDU0MSAxNy42NDE0IDE4LjYxMjMgMTcuMzEzNUMxOC43NzYzIDE2Ljk4NTUgMTguODU4MyAxNi42MDcyIDE4Ljg1ODQgMTYuMTc5N1YxMC41NTQ3QzE4Ljg1ODQgOS45NzQ3OCAxOC44NDA4IDkuNDExOTYgMTguODA1NyA4Ljg2NzE5QzE4Ljc3NjQgOC4zMjI0NCAxOC43MzI0IDcuODAzNTcgMTguNjczOCA3LjMxMTUyQzE4LjYyMTEgNi44MTM2NiAxOC41NTY2IDYuMzQ3NTIgMTguNDgwNSA1LjkxNDA2QzE4LjQwNDMgNS40ODA2NSAxOC4zMjUyIDUuMDc2MDQgMTguMjQzMiA0LjcwMTE3QzE4LjEzMTkgNC4xOTc0MyAxNy45NTg5IDMuNzY5NDcgMTcuNzI0NiAzLjQxNzk3QzE3LjQ5MDMgMy4wNjA2MiAxNy4xOTcyIDIuNzc5MjkgMTYuODQ1NyAyLjU3NDIyQzE2LjQ5NDIgMi4zNjkxNSAxNi4wODY5IDIuMjQwMjQgMTUuNjI0IDIuMTg3NUMxNS4zMDE4IDIuMTUyMzQgMTQuODEyNSAyLjExNzE5IDE0LjE1NjIgMi4wODIwM0MxMy41IDIuMDQxMDIgMTIuNzgyMiAyLjAyMDUxIDEyLjAwMjkgMi4wMjA1MVpNMTYuMTA3NCAxNC42MTUyQzE2LjQ1OSAxNC42MTUyIDE2Ljc0OSAxNC43MzI0IDE2Ljk3NzUgMTQuOTY2OEMxNy4yMTE4IDE1LjIwMTEgMTcuMzI5MSAxNS40ODg0IDE3LjMyOTEgMTUuODI4MUMxNy4zMjkgMTYuMTc5NSAxNy4yMTE4IDE2LjQ3MjggMTYuOTc3NSAxNi43MDdDMTYuNzQzMiAxNi45NDEyIDE2LjQ1MyAxNy4wNTg2IDE2LjEwNzQgMTcuMDU4NkMxNS43NjE4IDE3LjA1ODYgMTUuNDcxNiAxNi45NDEyIDE1LjIzNzMgMTYuNzA3QzE1LjAwMyAxNi40NzI4IDE0Ljg4NTkgMTYuMTc5NSAxNC44ODU3IDE1LjgyODFDMTQuODg1NyAxNS40ODg0IDE1LjAwMzEgMTUuMjAxMSAxNS4yMzczIDE0Ljk2NjhDMTUuNDcxNyAxNC43MzI0IDE1Ljc2MTcgMTQuNjE1MiAxNi4xMDc0IDE0LjYxNTJaTTcuODgwODYgMTQuNjI0QzguMjMyNDIgMTQuNjI0IDguNTIyNDYgMTQuNzM4MyA4Ljc1MDk4IDE0Ljk2NjhDOC45NzkzMyAxNS4xOTUzIDkuMDkzNzUgMTUuNDgyNSA5LjA5Mzc1IDE1LjgyODFDOS4wOTM2NCAxNi4xNzk1IDguOTc2NDUgMTYuNDcyOCA4Ljc0MjE5IDE2LjcwN0M4LjUxMzcxIDE2LjkzNTQgOC4yMjY0NCAxNy4wNDk4IDcuODgwODYgMTcuMDQ5OEM3LjUyOTQyIDE3LjA0OTggNy4yMzkyMiAxNi45MzU0IDcuMDEwNzQgMTYuNzA3QzYuNzg4MTkgMTYuNDcyOCA2LjY3Njg2IDE2LjE3OTUgNi42NzY3NiAxNS44MjgxQzYuNjc2NzYgMTUuNDgyNSA2Ljc5MTE4IDE1LjE5NTMgNy4wMTk1MyAxNC45NjY4QzcuMjQ4MDUgMTQuNzM4MyA3LjUzNTE2IDE0LjYyNCA3Ljg4MDg2IDE0LjYyNFpNMTIuMDAzOSA1LjU4ODg3QzEyLjgzNTkgNS41ODg4NyAxMy41MjczIDUuNTk3NjYgMTQuMDc4MSA1LjYxNTIzQzE0LjYyODkgNS42MzI4MSAxNS4wOTE4IDUuNjU2MjUgMTUuNDY2OCA1LjY4NTU1QzE1Ljg0NzcgNS43MDg5OCAxNi4xOTkyIDUuNzQxMjEgMTYuNTIxNSA1Ljc4MjIzQzE2LjcyMDcgNS44MDU2NiAxNi44Nzg5IDUuODgxODQgMTYuOTk2MSA2LjAxMDc0QzE3LjExOTEgNi4xMzk2NSAxNy4yMDQxIDYuMzAwNzggMTcuMjUxIDYuNDk0MTRDMTcuMjk3OSA2LjY5OTIyIDE3LjM0NzcgNi45ODkyNiAxNy40MDA0IDcuMzY0MjZDMTcuNDUzMSA3LjczOTI2IDE3LjQ5NzEgOC4xNzg3MSAxNy41MzIyIDguNjgyNjJDMTcuNTY3NCA5LjE4NjUyIDE3LjU4NSA5LjczNDM4IDE3LjU4NSAxMC4zMjYyVjEyLjM0NzdDMTcuNTg1IDEyLjU5MzggMTcuNTI5MyAxMi43OTg4IDE3LjQxOCAxMi45NjI5QzE3LjMwNjYgMTMuMTIxMSAxNy4xMTkxIDEzLjIxNzggMTYuODU1NSAxMy4yNTI5QzE2LjM4MDkgMTMuMzExNSAxNS43Mjc1IDEzLjM2MTMgMTQuODk1NSAxMy40MDIzQzE0LjA2OTMgMTMuNDQzNCAxMy4xMDU1IDEzLjQ2NjggMTIuMDAzOSAxMy40NzI3QzEwLjg5NjUgMTMuNDY2OCA5LjkyNjc2IDEzLjQ0MzQgOS4wOTQ3MyAxMy40MDIzQzguMjY4NTUgMTMuMzYxMyA3LjYxODE2IDEzLjMxMTUgNy4xNDM1NSAxMy4yNTI5QzYuODc5ODggMTMuMjE3OCA2LjY5MjM4IDEzLjEyMTEgNi41ODEwNSAxMi45NjI5QzYuNDY5NzMgMTIuNzk4OCA2LjQxNDA2IDEyLjU5MzggNi40MTQwNiAxMi4zNDc3VjEwLjMyNjJDNi40MTQwNiA5LjczNDM4IDYuNDMxNjQgOS4xODY1MiA2LjQ2NjggOC42ODI2MkM2LjUwMTk1IDguMTc4NzEgNi41NDU5IDcuNzM5MjYgNi41OTg2MyA3LjM2NDI2QzYuNjUxMzcgNi45ODkyNiA2LjcwMTE3IDYuNjk5MjIgNi43NDgwNSA2LjQ5NDE0QzYuNzk0OTIgNi4zMDA3OCA2Ljg3Njk1IDYuMTM5NjUgNi45OTQxNCA2LjAxMDc0QzcuMTExMzMgNS44ODE4NCA3LjI2MzY3IDUuODA1NjYgNy40NTExNyA1Ljc4MjIzQzcuNzg1MTYgNS43NDEyMSA4LjE0MjU4IDUuNzA4OTggOC41MjM0NCA1LjY4NTU1QzguOTA0MyA1LjY1NjI1IDkuMzcwMTIgNS42MzI4MSA5LjkyMDkgNS42MTUyM0MxMC40NzE3IDUuNTk3NjYgMTEuMTY2IDUuNTg4ODcgMTIuMDAzOSA1LjU4ODg3Wk0xMi4wMDM5IDcuMDM5MDZDMTEuMTc0NCA3LjAzOTA2IDEwLjQ5NjUgNy4wNDc1NSA5Ljk2NjggNy4wNjQ0NUM5LjQyOTM2IDcuMDgxNjEgOC45ODY3NyA3LjEwMzc5IDguNjM0NzcgNy4xMzA4Nkw4LjYyNDAyIDcuMTMxODRMOC42MTIzIDcuMTMyODFDOC40MzI4MiA3LjE0Mzg2IDguMjYwMzIgNy4xNTY4OSA4LjA5NDczIDcuMTcxODhDOC4wNzYyNCA3LjI4MzQzIDguMDU1NTQgNy40MTQ1MyA4LjAzNDE4IDcuNTY2NDFDNy45ODc0NCA3Ljg5ODgzIDcuOTQ2NiA4LjMwMjk4IDcuOTEzMDkgOC43ODMyQzcuODgwNjMgOS4yNDg0MiA3Ljg2NDI2IDkuNzYyNTEgNy44NjQyNiAxMC4zMjYyVjExLjg2ODJDOC4yMjAwOSAxMS44OTg5IDguNjUzMTkgMTEuOTI4NiA5LjE2Njk5IDExLjk1NDFDOS45Njk5IDExLjk5MzcgMTAuOTE0NCAxMi4wMTU2IDEyLjAwMjkgMTIuMDIxNUMxMy4wODY2IDEyLjAxNTYgMTQuMDI1OCAxMS45OTM3IDE0LjgyMzIgMTEuOTU0MUgxNC44MjQyQzE1LjM0MjIgMTEuOTI4NiAxNS43Nzc2IDExLjg5ODkgMTYuMTM0OCAxMS44NjgyVjEwLjMyNjJDMTYuMTM0OCA5Ljc2MjUxIDE2LjExODQgOS4yNDg0MiAxNi4wODU5IDguNzgzMkMxNi4wNTI0IDguMzAyOTggMTYuMDExNiA3Ljg5ODgzIDE1Ljk2NDggNy41NjY0MUMxNS45NDM1IDcuNDE0ODkgMTUuOTIxOCA3LjI4NDIzIDE1LjkwMzMgNy4xNzI4NUMxNS43Mzc1IDcuMTU3NDMgMTUuNTYyNCA3LjE0NDE3IDE1LjM3NzkgNy4xMzI4MUwxNS4zNjYyIDcuMTMxODRMMTUuMzUzNSA3LjEzMDg2QzE1LjAwODQgNy4xMDM5MSAxNC41Njk2IDcuMDgxNjEgMTQuMDMyMiA3LjA2NDQ1QzEzLjUwMjUgNy4wNDc1NSAxMi44Mjc0IDcuMDM5MDYgMTIuMDAzOSA3LjAzOTA2Wk0xNC4yNDQxIDMuMTk4MjRDMTQuNDI1OCAzLjE5ODI0IDE0LjU3MjMgMy4yNTM5MSAxNC42ODM2IDMuMzY1MjNDMTQuNzk0OCAzLjQ3NjUzIDE0Ljg1MDYgMy42MjAyNSAxNC44NTA2IDMuNzk1OUMxNC44NTA1IDMuOTcxNDYgMTQuNzk0OCA0LjExODI3IDE0LjY4MzYgNC4yMzUzNUMxNC41NzIzIDQuMzQ2NTIgMTQuNDI1NiA0LjQwMjM0IDE0LjI0NDEgNC40MDIzNEg5Ljc1MjkzQzkuNTcxNDIgNC40MDIzNCA5LjQyNDc3IDQuMzQ2NTIgOS4zMTM0OCA0LjIzNTM1QzkuMjA4MTEgNC4xMTgyNyA5LjE1NTM3IDMuOTcxNDYgOS4xNTUyNyAzLjc5NTlDOS4xNTUyNyAzLjYyMDI1IDkuMjA4MTcgMy40NzY1MyA5LjMxMzQ4IDMuMzY1MjNDOS40MjQ4IDMuMjUzOTEgOS41NzEyOSAzLjE5ODI0IDkuNzUyOTMgMy4xOTgyNEgxNC4yNDQxWiIgZmlsbD0iYmxhY2siLz4KPC9nPgo8ZGVmcz4KPGNsaXBQYXRoIGlkPSJjbGlwMF80NTg0XzMxNiI+CjxyZWN0IHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgZmlsbD0id2hpdGUiLz4KPC9jbGlwUGF0aD4KPC9kZWZzPgo8L3N2Zz4K");
}
.journey-tag.flight::before {
  display: block;
  background-image: url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAwXzQ1ODRfMzE0KSI+CjxwYXRoIGQ9Ik0xNS44MTI1IDE5LjM5NTRDMTUuOTczNSAxOS43OTQgMTYuNDg5MSAxOS44OTg4IDE2Ljc5MzEgMTkuNTk0OUwxNy40NTg2IDE4LjkyOTRDMTcuNzM1OSAxOC42NTIgMTcuODYwMiAxOC4yNTY2IDE3Ljc5MTQgMTcuODcwNEwxNi40MDk5IDEwLjExNDFMMjAuMzE4NCA2LjQ1MzI1QzIxLjU0NTkgNS4yNzgzMyAyMS4yNTM0IDMuNzQzNzcgMjAuNzU1NyAzLjI0NjAxQzIwLjI1NzkgMi43NDgyNSAxOC42NjIyIDIuNTMxOTUgMTcuNTUwNiAzLjY4NTVMMTMuODk1MSA3LjU5OTMyTDYuMTMxNjggNi4yMTA3NkM1Ljc0NTI1IDYuMTQxNjUgNS4zNDk0NSA2LjI2NTkxIDUuMDcxODcgNi41NDM0OUw0LjQwNjM3IDcuMjA4OThDNC4xMDI1MyA3LjUxMjgzIDQuMjA3MjIgOC4wMjgyMSA0LjYwNTU0IDguMTg5NDJMMTAuNzk4NSAxMC42OTU5TDcuMjM1MjMgMTQuNzAyMUw0Ljg1MTI3IDE0LjAxNzdDNC42NDE1NyAxMy45NTc1IDQuNDE1NzIgMTQuMDE1OSA0LjI2MTQ1IDE0LjE3MDFMMy4zMDY3OSAxNS4xMjQ4QzMuMTY1MjQgMTUuMjY2MyAzLjE5OTQgMTUuNTA0MiAzLjM3NTA5IDE1LjYwMDJMNi42MjY4MSAxNy4zNzY4TDguNDAxNTEgMjAuNjI2NUM4LjQ5NzQ3IDIwLjgwMjIgOC43MzUzNiAyMC44MzY0IDguODc2OTMgMjAuNjk0OEw5LjgzMTUzIDE5Ljc0MDJDOS45ODU4IDE5LjU4NTkgMTAuMDQ0MiAxOS4zNjAxIDkuOTgzOTcgMTkuMTUwNEw5LjI5OTYxIDE2Ljc2NjRMMTMuMzEzMyAxMy4yMTA3TDE1LjgxMjUgMTkuMzk1NFoiIHN0cm9rZT0iYmxhY2siIHN0cm9rZS13aWR0aD0iMS41Ii8+CjwvZz4KPGRlZnM+CjxjbGlwUGF0aCBpZD0iY2xpcDBfNDU4NF8zMTQiPgo8cmVjdCB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIGZpbGw9IndoaXRlIi8+CjwvY2xpcFBhdGg+CjwvZGVmcz4KPC9zdmc+Cg==");
}
.journey-title {
  min-width: 0;
}
.journey-title h2 {
  margin: 9px 0 6px;
  overflow-wrap: anywhere;
  font-size: 24px;
  line-height: 1;
  font-weight: 850;
}
.journey-title p {
  margin: 0;
  overflow-wrap: anywhere;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.42;
}
.journey-selected {
  width: fit-content;
  margin-top: 8px;
  border-radius: 999px;
  padding: 5px 9px;
  background: var(--source);
  color: var(--void);
  font-size: 10px;
  font-weight: 840;
  line-height: 1;
}
.journey-conflict {
  width: fit-content;
  max-width: 100%;
  margin-top: 8px;
  border-radius: 9px;
  padding: 6px 9px;
  background: var(--danger-soft);
  color: var(--danger);
  font-size: 11px;
  font-weight: 840;
  line-height: 1.35;
  overflow-wrap: anywhere;
}
.journey-expand {
  border: 1px solid var(--line);
  border-radius: 999px;
  min-width: 52px;
  min-height: 36px;
  padding: 8px 11px;
  background: var(--ink);
  color: var(--void);
  font-size: 12px;
  font-weight: 800;
}
.journey-mainline {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  gap: 10px;
  align-items: center;
  margin-top: 10px;
}
.journey-price {
  grid-column: 4;
  justify-self: end;
  align-self: center;
  color: var(--source);
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.journey-price b {
  font-size: 18px;
  line-height: 1;
  font-weight: 850;
}
.time-block {
  min-width: 0;
}
.time-block b {
  display: block;
  overflow-wrap: normal;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
  font-size: 22px;
  line-height: 1;
}
.time-block span {
  display: block;
  margin-top: 5px;
  overflow-wrap: anywhere;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.25;
}
.track {
  position: relative;
  width: 74px;
  height: 34px;
}
.track::before {
  content: "";
  position: absolute;
  left: 4px;
  right: 4px;
  top: 16px;
  height: 2px;
  background: linear-gradient(90deg, var(--source), rgba(23, 18, 13, 0.14));
}
.track::after {
  display: none;
}
.track small,
.track span,
.track i {
  position: absolute;
  z-index: 1;
  display: block;
  width: 100%;
  text-align: center;
}
.track small {
  top: -2px;
  overflow: hidden;
  color: var(--muted);
  font-size: 8px;
  line-height: 1;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.track i { display: none; }
.track svg {
  position: absolute;
  z-index: 1;
  left: 50%;
  top: 9px;
  display: block;
  width: 13px;
  height: 13px;
  transform: translateX(-50%);
  color: var(--source);
}
.track span {
  bottom: -1px;
  color: var(--muted);
  font-size: 8px;
  line-height: 1;
}
.journey-metrics {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  margin-top: 10px;
}
.journey-metric {
  min-width: 0;
  border-radius: 14px;
  padding: 8px;
  background: rgba(23, 18, 13, 0.05);
}
.journey-metric span {
  display: block;
  color: var(--muted);
  font-size: 10px;
  line-height: 1;
}
.journey-metric b {
  display: block;
  margin-top: 6px;
  overflow-wrap: anywhere;
  color: var(--ink);
  font-size: 13px;
  line-height: 1.18;
}
.journey-card:not(.expanded) .journey-detail { display: none; }
.journey-detail {
  position: relative;
  z-index: 1;
  margin-top: 11px;
  border-top: 1px solid var(--line);
  padding-top: 11px;
}
.detail-grid {
  display: grid;
  gap: 8px;
}
.detail-row {
  display: grid;
  grid-template-columns: 78px minmax(0, 1fr);
  gap: 10px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.detail-row b {
  color: var(--ink);
  font-weight: 760;
}
.journey-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 11px;
}
.journey-actions-persistent {
  position: relative;
  z-index: 1;
  border-top: 1px solid var(--line);
  padding-top: 11px;
}
.journey-action {
  border: 0;
  border-radius: 999px;
  min-height: 42px;
  padding: 10px 14px;
  background: var(--source);
  color: #fffaf1;
  font-size: 13px;
  font-weight: 830;
}
.journey-action.secondary {
  background: var(--ink);
  color: var(--void);
  border: 1px solid var(--line);
}
.journey-action.danger {
  border: 1px solid var(--danger);
  background: var(--danger);
  color: #fff;
}
@media (min-width: 680px) {
  .route-hero { min-height: 430px; padding: 36px 28px 28px; }
  .route-hero h1 { font-size: 58px; }
  .journey-board { padding-left: 22px; padding-right: 22px; grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .journey-card.featured { grid-column: 1 / -1; }
}
@media (max-width: 380px) {
  .route-hero h1 { font-size: 40px; }
  .route-map { padding: 10px; }
  .route-cities { grid-template-columns: minmax(0, 1fr) 42px minmax(0, 1fr); gap: 6px; }
  .route-city { min-height: 74px; padding: 10px; }
  .route-city b { font-size: 17px; }
  .route-mid { width: 42px; height: 30px; }
  .route-mid::before { left: 5px; right: 5px; top: 18px; }
  .track { display: none; }
  .route-stats { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
  .route-stat { padding: 8px 7px; }
  .route-stat b { font-size: 13px; }
  .journey-mainline { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) auto; }
  .journey-price { grid-column: 3; }
  .journey-metrics { grid-template-columns: 1fr; }
}
@media (prefers-reduced-motion: no-preference) {
  .route-mid::after, .track::after { animation: travelPulse 2.6s ease-in-out infinite; }
  .journey-card { transition: transform 180ms ease, border-color 180ms ease; }
  .journey-card:active { transform: scale(0.992); }
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.001ms !important;
  }
}
@keyframes travelPulse {
  0%, 100% { opacity: 0.72; }
  50% { opacity: 1; }
}
.route-hero {
  min-height: 280px;
}
.route-hero h1 {
  font-family: inherit;
  font-size: 34px;
  line-height: 1.04;
}
.route-map {
  border-radius: 20px;
}
.journey-card {
  border-radius: 16px;
  box-shadow: none;
}
.route-city,
.route-stat,
.journey-metric {
  border-radius: 12px;
}
.travel-control,
.journey-expand,
.journey-action {
  transition: transform 140ms ease, background-color 140ms ease, border-color 140ms ease;
}
.travel-control:active,
.journey-expand:active,
.journey-action:active,
.journey-card:active {
  transform: scale(0.98);
}

/* Travel scene v2: match the shared Appless scene hierarchy. */
.itinerary-shell {
  width: min(100%, 820px);
  background: transparent;
  padding: 10px 15px 104px;
}
.route-hero {
  min-height: 0;
  padding: 11px 3px 0;
  display: block;
}
.route-hero::before,
.route-hero::after {
  display: none;
}
.route-title {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  padding: 0 0 16px;
}
.route-title > div {
  min-width: 0;
}
.route-date {
  display: block;
  margin-bottom: 6px;
  color: var(--muted);
  font-size: 11px;
  line-height: 1;
}
.route-title h1 {
  margin: 0;
  max-width: none;
  color: var(--ink-soft);
  font-family: inherit;
  font-size: 28px;
  line-height: 1.15;
  font-weight: 520;
  letter-spacing: -0.025em;
}
.route-title p {
  margin: 6px 0 0;
  max-width: 100%;
  border: 0;
  border-radius: 0;
  padding: 0;
  background: transparent;
  color: var(--muted);
  font-size: 12px;
  font-weight: 400;
  line-height: 1.45;
}
.route-date-action {
  position: relative;
  display: grid;
  place-items: center;
  flex: 0 0 auto;
  width: 35px;
  height: 35px;
  padding: 0;
  border: 1px solid rgba(126, 96, 77, 0.14);
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.78);
  color: var(--ink-soft);
  box-shadow: 0 4px 12px rgba(85, 61, 45, 0.08);
}
.route-date-action::before {
  display: none;
}
.route-date-action svg {
  width: 18px;
  height: 18px;
}
.route-kicker { display: none; }
.route-hero .persona-banner { display: none; }
.route-map {
  margin-top: 0;
  border: 1px solid rgba(106, 78, 60, 0.12);
  border-radius: 23px;
  padding: 15px;
  background: rgba(255, 255, 255, 0.67);
  box-shadow: 0 10px 28px rgba(91, 65, 48, 0.07);
  backdrop-filter: blur(22px);
}
.route-city {
  border-radius: 12px;
  padding: 8px;
  background: rgba(245, 240, 235, 0.72);
}
.route-city b {
  font-size: 16px;
  font-weight: 500;
}
.route-city span {
  margin-top: 4px;
  font-size: 10px;
}
.route-mid {
  width: 54px;
  height: 36px;
}
.route-mid::before {
  left: 3px;
  right: 3px;
  top: 22px;
  height: 1px;
}
.route-mid::after {
  top: 7px;
  width: 25px;
  height: 25px;
  background-size: 15px 15px;
}
.route-stats {
  gap: 7px;
  margin-top: 10px;
  padding-top: 11px;
  border-top: 1px solid rgba(73, 63, 56, 0.08);
}
.route-stat {
  padding: 8px;
  border-radius: 12px;
  background: rgba(245, 240, 235, 0.72);
}
.route-stat span { font-size: 9px; }
.route-stat b {
  margin-top: 3px;
  font-size: 12px;
  font-weight: 500;
}
.travel-controls {
  position: static;
  display: block;
  padding: 12px 0 0;
  border-bottom: 0;
  background: transparent;
  backdrop-filter: none;
}
.travel-primary-tabs {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 4px;
  padding: 4px;
  border-radius: 15px;
  background: rgba(92, 70, 57, 0.08);
}
.travel-tool-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 10px;
}
.travel-primary-tabs .travel-control {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  width: 100%;
  min-height: 36px;
  padding: 6px 8px;
  border: 0;
  border-radius: 11px;
  background: transparent;
  color: #75665c;
  font-size: 11px;
  font-weight: 400;
}
.travel-primary-tabs .travel-control.active {
  background: rgba(255, 255, 255, 0.86);
  color: var(--ink-soft);
  box-shadow: 0 3px 10px rgba(75, 53, 40, 0.06);
}
.travel-tool-row .travel-control {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  min-height: 31px;
  padding: 6px 9px;
  border: 1px solid rgba(73, 63, 56, 0.1);
  background: rgba(255, 255, 255, 0.57);
  color: #68584e;
  font-size: 10px;
  font-weight: 400;
}
.travel-tool-row .travel-control.active {
  border-color: var(--accent);
  background: var(--accent-soft);
  color: var(--accent);
}
.travel-control svg {
  width: 13px;
  height: 13px;
  flex: 0 0 13px;
}
.journey-board {
  gap: 10px;
  margin-top: 12px;
  padding: 0 0 20px;
}
.journey-card {
  border-radius: 21px;
  padding: 14px;
  background: rgba(255, 255, 255, 0.69);
  box-shadow: 0 10px 26px rgba(82, 59, 44, 0.07);
  backdrop-filter: blur(22px);
}
.journey-card::before,
.journey-card::after {
  display: none;
}
.journey-card:not(.featured) {
  box-shadow: none;
}
.journey-card.compact {
  border-radius: 21px;
  box-shadow: none;
}
.journey-title h2 {
  display: none;
}
.journey-tag {
  min-height: 24px;
  padding: 4px 7px;
  font-size: 9px;
  font-weight: 500;
}
.journey-expand {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  min-width: auto;
  min-height: 24px;
  padding: 3px 0;
  border: 0;
  background: transparent;
  color: var(--accent);
  font-size: 10px;
  font-weight: 400;
}
.journey-expand::after { display: none; }
.journey-expand svg { width: 12px; height: 12px; }
.journey-mainline {
  grid-template-columns: minmax(0, 1fr) 92px minmax(0, 1fr);
  margin-top: 13px;
}
.time-block b {
  font-size: 22px;
  font-weight: 500;
}
.time-block span { font-size: 10px; }
.track {
  width: 74px;
  height: 28px;
}
.track::before { top: 14px; }
.track::after { top: 8px; }
.journey-trip-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 13px;
  padding-top: 10px;
  border-top: 1px solid rgba(73, 63, 56, 0.08);
  color: var(--muted);
  font-size: 10px;
}
.journey-trip-meta .journey-code {
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.journey-trip-meta .journey-availability {
  overflow-wrap: anywhere;
}
.journey-trip-meta .journey-price {
  margin-left: auto;
  color: var(--ink-soft);
  font-size: 13px;
  font-weight: 500;
  white-space: nowrap;
}
.journey-conflict {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-top: 9px;
  padding: 8px 9px;
  border-radius: 11px;
  background: rgba(176, 74, 66, 0.08);
  color: #9b4f48;
  font-size: 9px;
  line-height: 1.35;
}
.journey-conflict::before {
  display: none;
}
.journey-conflict svg {
  flex: 0 0 14px;
  width: 14px;
  height: 14px;
}
.journey-conflict b { font-weight: 500; }
.journey-expanded-grid {
  display: none;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 7px;
  margin-top: 9px;
}
.journey-card.expanded .journey-expanded-grid { display: grid; }
.journey-expanded-grid > span {
  min-width: 0;
  padding: 8px;
  border-radius: 11px;
  background: rgba(245, 240, 235, 0.64);
}
.journey-expanded-grid small {
  display: block;
  color: #8b7d73;
  font-size: 8px;
  line-height: 1.2;
}
.journey-expanded-grid b {
  display: block;
  margin-top: 3px;
  overflow-wrap: anywhere;
  color: var(--ink-soft);
  font-size: 10px;
  font-weight: 500;
  line-height: 1.2;
}
.journey-metrics { display: none; }
.journey-metric {
  border-radius: 11px;
  padding: 8px;
  background: rgba(245, 240, 235, 0.64);
}
.journey-metric span { font-size: 8px; }
.journey-metric b {
  margin-top: 3px;
  font-size: 10px;
  font-weight: 500;
}
.journey-actions { gap: 6px; margin-top: 10px; }
.journey-actions-persistent {
  margin-top: 10px;
  border-top: 0;
  padding-top: 0;
}
.journey-action {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  min-height: 34px;
  padding: 7px 10px;
  border-radius: 11px;
  font-size: 9px;
  font-weight: 500;
}
.journey-action svg {
  width: 13px;
  height: 13px;
  flex: 0 0 13px;
}
.journey-action.secondary {
  border: 1px solid rgba(153, 95, 76, 0.16);
  background: rgba(255, 255, 255, 0.72);
  color: #795c4a;
}
.journey-card.featured:not(.expanded) .journey-actions-persistent { display: none; }
.journey-detail {
  margin-top: 10px;
  padding-top: 0;
  border-top: 0;
}
.journey-detail .detail-grid { display: none; }
.journey-detail .journey-actions { margin-top: 0; }
.detail-row {
  grid-template-columns: 72px minmax(0, 1fr);
  font-size: 10px;
}

/* Keep travel typography aligned with the shared scene hierarchy. */
.route-date { font-size: 12px; }
.route-title h1 { font-size: 32px; }
.route-title p { font-size: 15px; }
.route-city b { font-size: 18px; }
.route-city span { font-size: 12px; }
.route-stat span { font-size: 12px; }
.route-stat b { font-size: 15px; }
.travel-primary-tabs .travel-control,
.travel-tool-row .travel-control { font-size: 13px; }
.journey-tag { font-size: 12px; }
.journey-expand { font-size: 13px; }
.time-block span { font-size: 12px; }
.journey-trip-meta { font-size: 12px; }
.journey-trip-meta .journey-price { font-size: 15px; }
.journey-conflict { font-size: 12px; }
.journey-expanded-grid small,
.journey-metric span { font-size: 12px; }
.journey-expanded-grid b,
.journey-metric b { font-size: 15px; }
.journey-action { font-size: 13px; }
.detail-row { font-size: 15px; }
@media (min-width: 680px) {
  .route-hero { min-height: 0; padding: 11px 3px 0; }
  .route-title h1 { font-size: 32px; }
  .journey-board { padding-left: 0; padding-right: 0; }
}
@media (max-width: 380px) {
  .route-title h1 { font-size: 30px; }
  .route-map { padding: 12px; }
  .journey-mainline { grid-template-columns: minmax(0, 1fr) 54px minmax(0, 1fr); }
  .journey-metrics { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}

/* AIOS Demo travel results: query header -> route -> filters -> flat options. */
html,
body {
  min-height: 100%;
  background: #f8fafc;
}
.itinerary-shell {
  width: min(100%, 820px);
  min-height: 100vh;
  margin: 0 auto;
  padding: 22px 24px calc(112px + env(safe-area-inset-bottom, 0px));
  overflow-x: hidden;
  background: linear-gradient(180deg, #b9d3ff 0%, #cae2ff 18%, #e4f0fb 38%, #f5f8fb 62%, #f8fafc 100%);
}
.route-hero {
  min-height: 0;
  padding: 0;
}
.route-title {
  padding: 0 8px;
}
.route-date {
  margin: 0 0 7px;
  color: #697278;
  font-size: 16px;
  font-weight: 700;
  line-height: 22px;
}
.route-title h1 {
  max-width: 350px;
  color: #101215;
  font-size: 31px;
  font-weight: 780;
  line-height: 38px;
  letter-spacing: -1.15px;
}
.route-title p {
  margin: 7px 0 0;
  color: #7d858b;
  font-size: 14px;
  font-weight: 560;
  line-height: 20px;
}
.route-date-action {
  width: 44px;
  height: 44px;
  border: 1px solid rgba(84, 92, 100, 0.12);
  background: rgba(255, 255, 255, 0.88);
  color: #24282c;
  box-shadow: none;
}
.route-map {
  margin: 27px 8px 0;
  padding: 0 0 24px;
  border: 0;
  border-bottom: 1px solid rgba(63, 70, 77, 0.12);
  border-radius: 0;
  background: transparent;
  box-shadow: none;
  backdrop-filter: none;
}
.route-label {
  margin: 0 0 20px;
  color: #6e777d;
  font-size: 17px;
  font-weight: 700;
  line-height: 23px;
}
.route-cities {
  grid-template-columns: max-content 56px max-content;
  justify-content: center;
  gap: 9px;
}
.route-city {
  display: flex;
  min-width: 88px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 10px 19px 11px;
  border-radius: 22px;
  background: rgba(244, 247, 250, 0.7);
  backdrop-filter: blur(16px) saturate(122%);
}
.route-city b {
  color: #111317;
  font-size: 27px;
  font-weight: 780;
  line-height: 33px;
  letter-spacing: -0.85px;
}
.route-city span {
  margin-top: 7px;
  color: #899095;
  font-size: 14px;
  font-weight: 620;
  line-height: 19px;
}
.route-mid {
  width: 56px;
  height: 42px;
}
.route-mid::before {
  left: 2px;
  right: 2px;
  top: 20px;
  height: 1px;
  background: #cbd0d4;
  clip-path: none;
}
.route-mid::after {
  content: "→";
  top: 21px;
  display: grid;
  width: 28px;
  height: 28px;
  place-items: center;
  border: 0;
  background: rgba(228, 240, 251, 0.96);
  background-image: none;
  color: #202428;
  font-size: 25px;
  line-height: 28px;
  box-shadow: none;
}
.travel-controls {
  position: static;
  display: flex;
  width: 100%;
  align-items: center;
  gap: 7px;
  margin-top: 19px;
  overflow-x: auto;
  padding: 1px 0 4px;
  background: transparent;
  scrollbar-width: none;
}
.travel-controls::-webkit-scrollbar { display: none; }
.travel-primary-tabs,
.travel-tool-row { display: contents; }
.travel-primary-tabs .travel-control,
.travel-tool-row .travel-control {
  display: inline-flex;
  width: auto;
  height: 37px;
  min-height: 37px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  gap: 7px;
  margin: 0;
  padding: 0 14px;
  border: 1px solid rgba(84, 92, 100, 0.12);
  border-radius: 19px;
  background: rgba(255, 255, 255, 0.88);
  color: #545c62;
  box-shadow: none;
  font-size: 14px;
  font-weight: 660;
  line-height: 20px;
  white-space: nowrap;
}
.travel-primary-tabs .travel-control.active,
.travel-tool-row .travel-control.active {
  border-color: #24282c;
  background: #24282c;
  color: #ffffff;
  box-shadow: none;
}
.travel-control svg { width: 14px; height: 14px; flex-basis: 14px; }
.journey-board {
  gap: 11px;
  margin-top: 14px;
  padding: 0 0 20px;
}
.journey-card,
.journey-card.compact {
  position: relative;
  display: flex;
  min-height: 104px;
  flex-direction: column;
  margin: 0;
  padding: 18px 19px;
  border: 1px solid transparent;
  border-radius: 24px;
  background: #eef1f3;
  box-shadow: none;
  backdrop-filter: none;
}
.journey-card.selected {
  border-color: rgba(66, 117, 201, 0.34);
  background: #e7effa;
  box-shadow: none;
}
.journey-mainline {
  order: 1;
  display: flex;
  align-items: baseline;
  gap: 7px;
  margin: 0;
  padding-right: 74px;
}
.time-block b {
  color: #15181b;
  font-size: 23px;
  font-weight: 760;
  line-height: 29px;
  letter-spacing: -0.5px;
}
.time-block span { display: none; }
.track {
  display: inline-flex;
  width: auto;
  height: auto;
  align-items: baseline;
}
.track::before { display: none; }
.track::after {
  content: "→";
  position: static;
  display: block;
  width: auto;
  height: auto;
  border: 0;
  background: none;
  color: #15181b;
  font-size: 22px;
  line-height: 29px;
  transform: none;
}
.track small,
.track span,
.track svg { display: none; }
.journey-top {
  order: 2;
  display: flex;
  align-items: center;
  margin-top: 7px;
}
.journey-title {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 8px;
}
.journey-title h2 {
  display: block;
  min-width: 0;
  margin: 0;
  overflow: hidden;
  color: #555d63;
  font-size: 15px;
  font-weight: 690;
  line-height: 21px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.journey-tag {
  min-height: 25px;
  flex: 0 0 auto;
  padding: 0;
  border: 0;
  background: transparent;
  color: #555d63;
  font-size: 15px;
  font-weight: 690;
  line-height: 21px;
}
.journey-tag::before { width: 25px; height: 25px; flex-basis: 25px; }
.journey-expand {
  min-width: 44px;
  min-height: 32px;
  margin-left: auto;
  padding: 0 0 0 8px;
  color: #737b81;
  font-size: 13px;
  font-weight: 620;
}
.journey-trip-meta {
  position: static;
  order: 3;
  margin-top: 6px;
  padding: 0;
  border: 0;
  color: #737b81;
  font-size: 13px;
}
.journey-code { display: none; }
.journey-trip-meta .journey-price {
  position: absolute;
  top: 19px;
  right: 19px;
  margin: 0;
  color: #15181b;
  font-size: 21px;
  font-weight: 760;
  line-height: 27px;
}
.journey-conflict { order: 4; }
.journey-expanded-grid { order: 5; }
.journey-detail { order: 6; }
.journey-card.expanded {
  border-color: rgba(66, 117, 201, 0.34);
  background: #e7effa;
}
.journey-expanded-grid > span,
.journey-metric { background: rgba(255, 255, 255, 0.62); }
.journey-action {
  min-height: 40px;
  border-radius: 20px;
  background: #24282c;
  color: #ffffff;
}
.journey-action.secondary {
  border-color: rgba(84, 92, 100, 0.16);
  background: rgba(255, 255, 255, 0.88);
  color: #545c62;
}
@media (min-width: 680px) {
  .itinerary-shell { padding-right: 32px; padding-left: 32px; }
  .journey-board { grid-template-columns: 1fr; }
  .journey-card.featured { grid-column: auto; }
}
@media (max-width: 380px) {
  .itinerary-shell { padding-right: 18px; padding-left: 18px; }
  .route-title h1 { font-size: 29px; line-height: 35px; }
  .route-cities { grid-template-columns: max-content 42px max-content; gap: 6px; }
  .route-city { min-width: 78px; padding-right: 14px; padding-left: 14px; }
  .route-city b { font-size: 24px; }
  .journey-mainline { padding-right: 68px; }
  .time-block b { font-size: 21px; }
}
/* The native shell owns the full-screen scene gradient in immersive result mode. */
html,
body,
.itinerary-shell { background: transparent; }
.itinerary-shell {
  padding-top: 14px;
  padding-bottom: calc(112px + env(safe-area-inset-bottom, 0px));
}
.route-title h1 {
  max-width: 360px;
  display: -webkit-box;
  overflow: hidden;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.route-map { margin-top: 25px; }
.travel-controls { margin-top: 18px; }
.travel-primary-tabs .travel-control.has-chevron::after {
  content: '';
  width: 7px;
  height: 7px;
  margin: 0 1px 4px 0;
  border-right: 1.7px solid currentColor;
  border-bottom: 1.7px solid currentColor;
  transform: rotate(45deg);
}
.journey-expand { display: none; }
.journey-title { gap: 8px; }
.journey-airline-logo {
  display: block;
  width: 25px;
  height: 25px;
  flex: 0 0 25px;
  object-fit: contain;
}
.journey-title h2 {
  color: #737b81;
  font-size: 15px;
  font-weight: 580;
  line-height: 21px;
}
.journey-trip-meta .journey-price { font-size: 21px; }
@media (max-width: 380px) {
  .itinerary-shell { padding-top: 11px; }
  .route-map { margin-top: 21px; }
  .route-city { min-width: 74px; padding-right: 13px; padding-left: 13px; }
  .route-city b { font-size: 23px; line-height: 29px; }
}
`;

const TRAVEL_HOME_JS: string = `
(function () {
  var node = document.getElementById('home-data');
  var data = {};
  try { data = JSON.parse(node && node.textContent ? node.textContent : '{}') || {}; } catch (error) { data = {}; }
  var app = document.getElementById('app');
  if (!app) { return; }
  function text(value) { return value === undefined || value === null ? '' : String(value); }
  function list(value) { return Array.isArray(value) ? value : []; }
  var activatedFilter = list(data.actions).find(function (action) {
    return text(action && action.variant) === 'activated' &&
      ['travel_show_all', 'travel_filter_train', 'travel_filter_flight'].indexOf(text(action && action.id)) >= 0;
  });
  var initialMode = text(activatedFilter && activatedFilter.id) === 'travel_filter_train' ? 'train' :
    (text(activatedFilter && activatedFilter.id) === 'travel_filter_flight' ? 'flight' : 'all');
  var state = { mode: initialMode, trainFastest: false, trainAvailable: false, trainShowMore: false, expandedKey: '' };
  var isBusy = text(data.isBusy).toLowerCase() === 'true';
  function add(parent, tag, className, value) {
    var el = document.createElement(tag);
    if (className) { el.className = className; }
    if (value !== undefined && value !== null && text(value).length > 0) { el.textContent = text(value); }
    parent.appendChild(el);
    return el;
  }
  function icon(parent, name) {
    var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('width', '14');
    svg.setAttribute('height', '14');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '1.8');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.setAttribute('aria-hidden', 'true');
    var shapes = {
      'calendar-days': [['rect', { x: '3', y: '4', width: '18', height: '17', rx: '2' }], ['path', { d: 'M16 2v4M8 2v4M3 10h18M8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01M16 18h.01' }]],
      'calendar-plus': [['rect', { x: '3', y: '4', width: '18', height: '17', rx: '2' }], ['path', { d: 'M16 2v4M8 2v4M3 10h18M12 14v5M9.5 16.5h5' }]],
      'calendar-x': [['rect', { x: '3', y: '4', width: '18', height: '17', rx: '2' }], ['path', { d: 'M16 2v4M8 2v4M3 10h18M10 14l4 4M14 14l-4 4' }]],
      'zap': [['path', { d: 'M13 2 3 14h7l-1 8 11-14h-7z' }]],
      'ticket-check': [['path', { d: 'M3 7h18v4a2 2 0 0 0 0 4v4H3v-4a2 2 0 0 0 0-4z' }], ['path', { d: 'm8 15 2 2 5-5' }]],
      'list-filter': [['path', { d: 'M4 6h16M7 12h10M10 18h4' }]],
      'calendar-sync': [['path', { d: 'M4 4h16v16H4zM8 2v4M16 2v4M4 10h16' }], ['path', { d: 'm8 15 2 2 3-3M16 17h3' }]],
      'refresh-cw': [['path', { d: 'M20 11a8 8 0 0 0-14.8-4L3 10M3 5v5h5M4 13a8 8 0 0 0 14.8 4L21 14M21 19v-5h-5' }]],
      'chevron-up': [['path', { d: 'm6 15 6-6 6 6' }]],
      'chevron-down': [['path', { d: 'm6 9 6 6 6-6' }]],
      'plane': [['path', { d: 'M2 16l20-8-8-3-3-3-2 1 2 5-6 3-3-1z' }]],
      'train-front': [['rect', { x: '5', y: '3', width: '14', height: '16', rx: '3' }], ['path', { d: 'M8 19l-2 3M16 19l2 3M5 12h14M8 7h.01M16 7h.01' }]],
      'pin': [['path', { d: 'M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12z' }], ['circle', { cx: '12', cy: '9', r: '2' }]],
      'arrow-up-right': [['path', { d: 'M7 17 17 7M7 7h10v10' }]],
      'book-ticket': [['rect', { x: '3', y: '5', width: '18', height: '14', rx: '2' }], ['path', { d: 'M8 9h8M8 13h5' }]]
    };
    var parts = shapes[name] || shapes['book-ticket'];
    parts.forEach(function (shape) {
      var child = document.createElementNS('http://www.w3.org/2000/svg', shape[0]);
      var attrs = shape[1];
      Object.keys(attrs).forEach(function (key) { child.setAttribute(key, attrs[key]); });
      svg.appendChild(child);
    });
    parent.appendChild(svg);
    return svg;
  }
  function metric(block, labels) {
    var items = list(block && block.metrics).concat(list(block && block.rows));
    for (var i = 0; i < items.length; i += 1) {
      var label = text(items[i] && items[i].label);
      if (labels.indexOf(label) >= 0) { return text(items[i] && items[i].value); }
    }
    return '';
  }
  function numberIn(value) {
    var match = text(value).replace(/,/g, '').match(/[0-9]+(?:\\.[0-9]+)?/);
    return match ? Number(match[0]) : Number.NaN;
  }
  function durationMinutes(value) {
    var raw = text(value);
    var colon = raw.match(/([0-9]+):([0-9]+)/);
    if (colon) { return Number(colon[1]) * 60 + Number(colon[2]); }
    var hours = raw.match(/([0-9]+)\\s*(?:h|小时|时)/i);
    var minutes = raw.match(/([0-9]+)\\s*(?:m|分钟|分)/i);
    var total = (hours ? Number(hours[1]) * 60 : 0) + (minutes ? Number(minutes[1]) : 0);
    return total > 0 ? total : 999999;
  }
  function displayTime(value) {
    var raw = text(value).trim();
    var match = raw.match(/([01]?\\d|2[0-3]):([0-5]\\d)(?::[0-5]\\d)?/);
    if (!match) { return raw; }
    return (match[1].length === 1 ? '0' + match[1] : match[1]) + ':' + match[2];
  }
  function trainPrice(value) {
    var raw = text(value).trim().replace(/^¥+/, '').replace(/起+$/, '').trim();
    return raw.length > 0 ? '¥' + raw + '起' : '';
  }
  function flightPrice(value) {
    var raw = text(value).trim().replace(/^¥+/, '').replace(/起+$/, '').trim();
    return raw.length > 0 ? '¥' + raw : '';
  }
  function available(value) {
    var raw = text(value);
    if (raw.indexOf('有') >= 0 || raw.toLowerCase().indexOf('available') >= 0) { return true; }
    if (raw.indexOf('无') >= 0 && raw.indexOf('有') < 0) { return false; }
    return /[1-9][0-9]*/.test(raw);
  }
  function sourceKind(block) {
    var kind = text(block && block.kind).toLowerCase();
    var raw = [kind, text(block && block.source), metric(block, ['source', 'provider', 'sourceTag']), text(block && block.title), text(block && block.subtitle)].join(' ').toLowerCase();
    if (kind === 'train-option' || raw.indexOf('train') >= 0 || raw.indexOf('12306') >= 0 || raw.indexOf('高铁') >= 0) { return 'train'; }
    if (kind === 'flight-option' || raw.indexOf('flight') >= 0 || raw.indexOf('飞常准') >= 0 || raw.indexOf('航班') >= 0 || raw.indexOf('飞机') >= 0) { return 'flight'; }
    if (kind === 'food-result') { return 'food'; }
    return 'other';
  }
  function sourceLabel(block) {
    var source = sourceKind(block);
    var rawSource = text(block && block.source);
    if (source === 'train') { return rawSource.toLowerCase() === 'train' || rawSource.length === 0 ? '高铁 · 12306' : rawSource; }
    if (source === 'flight') { return rawSource.toLowerCase() === 'flight' || rawSource.length === 0 ? '飞机 · 飞常准' : rawSource; }
    if (source === 'food') { return text(block && block.source) || '餐饮'; }
    return text(block && block.source) || text(block && block.kind) || '结果';
  }
  function statusText(value) {
    var raw = text(value);
    var key = raw.toLowerCase();
    if (key === 'success' || key === 'available' || key === 'ready') { return '可选'; }
    if (key === 'scheduled') { return '计划'; }
    return raw;
  }
  function firstMetric(blocks, labels) {
    for (var i = 0; i < blocks.length; i += 1) {
      var value = metric(blocks[i], labels);
      if (value.length > 0) { return value; }
    }
    return '';
  }
  function shortest(blocks) {
    var best = '';
    var bestMinutes = 999999;
    blocks.forEach(function (block) {
      var value = metric(block, ['duration']);
      var minutes = durationMinutes(value);
      if (minutes < bestMinutes) {
        best = value;
        bestMinutes = minutes;
      }
    });
    return best;
  }
  function firstAction(actions, id) {
    var items = list(actions);
    for (var index = 0; index < items.length; index += 1) {
      if (text(items[index] && items[index].id) === id) { return items[index]; }
    }
    return null;
  }
  function headlinePlace(value) {
    var raw = text(value).trim().replace(/\s*T\d+$/i, '');
    return raw.replace(/(?:宝安|虹桥|浦东|首都|大兴|南站|北站|东站|西站|机场|火车站|站)$/,'') || raw;
  }
  function airlineLogoUrl(block) {
    var raw = metric(block, ['airline']).toLowerCase();
    if (raw.indexOf('深圳') >= 0 || raw.indexOf('shenzhen') >= 0) { return 'resource://rawfile/travel/airlines/shenzhen-airlines-symbol.png'; }
    if (raw.indexOf('南方') >= 0 || raw.indexOf('southern') >= 0) { return 'resource://rawfile/travel/airlines/china-southern.png'; }
    if (raw.indexOf('吉祥') >= 0 || raw.indexOf('juneyao') >= 0) { return 'resource://rawfile/travel/airlines/juneyao-air-symbol.png'; }
    if (raw.indexOf('春秋') >= 0 || raw.indexOf('spring') >= 0) { return 'resource://rawfile/travel/airlines/spring-airlines.png'; }
    if (raw.indexOf('东方') >= 0 || raw.indexOf('eastern') >= 0) { return 'resource://rawfile/travel/airlines/china-eastern.png'; }
    return '';
  }
  function postAction(action) {
    if (isBusy) { return; }
    try {
      if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
        window.AIPhoneHome.postAction(JSON.stringify({
          id: text(action.id),
          label: text(action.label || action.id),
          prompt: text(action.prompt),
          variant: text(action.variant),
          kind: text(action.kind),
          args: action.args && typeof action.args === 'object' ? action.args : null
        }));
      }
    } catch (error) {}
  }
  function setExpanded(key) {
    state.expandedKey = state.expandedKey === key ? '' : key;
    Array.prototype.slice.call(document.querySelectorAll('.journey-card')).forEach(function (card) {
      var expanded = card.getAttribute('data-card-key') === state.expandedKey;
      card.classList.toggle('expanded', expanded);
      card.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      var button = card.querySelector('.journey-expand');
      if (button) {
        button.textContent = expanded ? '收起' : '展开';
        icon(button, expanded ? 'chevron-up' : 'chevron-down');
      }
    });
  }
  function handleLocalAction(action) {
    if (isBusy) { return false; }
    var id = text(action && action.id);
    if (id === 'travel_show_all') { state.mode = 'all'; applyView(); if (action.args && action.args.taskId) { postAction(action); } return true; }
    if (id === 'travel_filter_train') { state.mode = 'train'; applyView(); if (action.args && action.args.taskId) { postAction(action); } return true; }
    if (id === 'travel_filter_flight') { state.mode = 'flight'; applyView(); if (action.args && action.args.taskId) { postAction(action); } return true; }
    if (id === 'client_show_more') { state.trainShowMore = !state.trainShowMore; applyView(); return true; }
    if (id === 'client_sort_fastest') { state.trainFastest = !state.trainFastest; applyView(); return true; }
    if (id === 'client_filter_available') { state.trainAvailable = !state.trainAvailable; applyView(); return true; }
    return false;
  }
  function updateControls() {
    Array.prototype.slice.call(document.querySelectorAll('.travel-control')).forEach(function (button) {
      var id = button.getAttribute('data-action') || '';
      var active = false;
      if (id === 'travel_show_all') { active = state.mode === 'all'; }
      if (id === 'travel_filter_train') { active = state.mode === 'train'; }
      if (id === 'travel_filter_flight') { active = state.mode === 'flight'; }
      if (id === 'client_show_more') { active = state.trainShowMore; }
      if (id === 'client_sort_fastest') { active = state.trainFastest; }
      if (id === 'client_filter_available') { active = state.trainAvailable; }
      button.classList.toggle('active', active);
    });
  }
  function applyView() {
    var board = document.querySelector('.journey-board');
    var cards = Array.prototype.slice.call(document.querySelectorAll('.journey-card'));
    cards.sort(function (left, right) {
      var leftSource = left.getAttribute('data-source') || '';
      var rightSource = right.getAttribute('data-source') || '';
      if (state.trainFastest && leftSource === 'train' && rightSource === 'train') {
        return durationMinutes(left.getAttribute('data-duration') || '') - durationMinutes(right.getAttribute('data-duration') || '');
      }
      return numberIn(left.getAttribute('data-index') || '') - numberIn(right.getAttribute('data-index') || '');
    });
    cards.forEach(function (card) { if (board) { board.appendChild(card); } });
    var visible = 0;
    var trainVisible = 0;
    cards.forEach(function (card) {
      var source = card.getAttribute('data-source') || '';
      var keep = true;
      if (state.mode === 'train') { keep = source === 'train'; }
      if (state.mode === 'flight') { keep = source === 'flight'; }
      if (source === 'train' && state.trainAvailable) { keep = keep && available(card.getAttribute('data-availability') || ''); }
      if (source === 'train' && keep) {
        trainVisible += 1;
        if (!state.trainShowMore && trainVisible > 6) { keep = false; }
      }
      if (keep) { visible += 1; }
      card.style.display = keep ? '' : 'none';
    });
    var count = document.getElementById('journey-count');
    if (count) { count.textContent = String(visible) + ' / ' + String(cards.length) + ' 条'; }
    var currentCount = document.getElementById('travel-current-count');
    if (currentCount) { currentCount.textContent = String(visible) + ' / ' + String(cards.length); }
    var empty = document.getElementById('journey-empty');
    if (empty) { empty.style.display = cards.length > 0 && visible === 0 ? '' : 'none'; }
    updateControls();
  }
  function detailRow(parent, label, value) {
    if (text(value).length === 0) { return; }
    var row = add(parent, 'div', 'detail-row');
    add(row, 'b', '', labelText(label));
    add(row, 'span', '', value);
  }
  function labelText(label) {
    var raw = text(label);
    if (raw === 'source') { return '来源'; }
    if (raw === 'from' || raw === 'dep') { return '出发'; }
    if (raw === 'to' || raw === 'arr') { return '到达'; }
    if (raw === 'depart' || raw === 'depTime') { return raw === 'depTime' ? '起飞' : '发车'; }
    if (raw === 'arrive' || raw === 'arrTime') { return raw === 'arrTime' ? '落地' : '到站'; }
    if (raw === 'recommendation') { return '推荐标签'; }
    if (raw === 'doorToDoorDuration') { return '门到门'; }
    if (raw === 'leaveOriginAt') { return '建议出发'; }
    if (raw === 'finalArrivalAt') { return '到最终目的地'; }
    if (raw === 'feasibilityReason') { return '会议判断'; }
    if (raw === 'duration') { return '耗时'; }
    if (raw === 'price') { return '价格'; }
    if (raw === 'availability' || raw === 'status') { return '状态'; }
    if (raw === 'seats') { return '座席'; }
    if (raw === 'business') { return '商务座'; }
    if (raw === 'first') { return '一等座'; }
    if (raw === 'second') { return '二等座'; }
    if (raw === 'noSeat') { return '无座'; }
    if (raw === 'hardSeat') { return '硬座'; }
    if (raw === 'sleeperSoft') { return '卧铺'; }
    if (raw === 'airline') { return '航司'; }
    if (raw === 'detail') { return '详情'; }
    return raw;
  }
  function isTravelCalendarAction(action) {
    return text(action && action.id) === 'travel.calendar.add';
  }
  function controlIcon(id) {
    if (id === 'client_sort_fastest') { return 'zap'; }
    if (id === 'client_filter_available') { return 'ticket-check'; }
    if (id === 'client_show_more') { return 'list-filter'; }
    if (id === 'travel_change_date') { return 'calendar-sync'; }
    if (id === 'travel_retry') { return 'refresh-cw'; }
    return '';
  }
  function actionIcon(action) {
    var raw = (text(action && action.id) + ' ' + text(action && action.label)).toLowerCase();
    if (raw.indexOf('calendar') >= 0 || raw.indexOf('日历') >= 0) { return 'calendar-plus'; }
    if (raw.indexOf('pin') >= 0 || raw.indexOf('固定') >= 0) { return 'pin'; }
    if (raw.indexOf('open') >= 0 || raw.indexOf('external') >= 0 || raw.indexOf('打开') >= 0) { return 'arrow-up-right'; }
    if (raw.indexOf('book') >= 0 || raw.indexOf('ticket') >= 0 || raw.indexOf('购票') >= 0 || raw.indexOf('订票') >= 0) { return 'book-ticket'; }
    return '';
  }
  function addActionButtons(parent, actions, persistent) {
    var kept = list(actions).filter(function (action) { return text(action && (action.label || action.id)).length > 0; });
    if (kept.length === 0) { return; }
    var row = add(parent, 'div', persistent ? 'journey-actions journey-actions-persistent' : 'journey-actions');
    kept.forEach(function (action, index) {
      var actionClass = text(action && action.variant) === 'danger' ? 'journey-action danger' :
        (index === 0 ? 'journey-action' : 'journey-action secondary');
      var button = add(row, 'button', actionClass);
      button.type = 'button';
      button.disabled = isBusy;
      var iconName = actionIcon(action);
      if (iconName.length > 0) { icon(button, iconName); }
      add(button, 'span', 'journey-action-label', action.label || action.id);
      button.addEventListener('click', function (event) {
        event.stopPropagation();
        if (isBusy) { return; }
        if (handleLocalAction(action)) { return; }
        postAction(action);
      });
    });
  }
  function renderPersonaBanner(parent) {
    var persona = data.persona || {};
    var name = text(persona.name);
    if (text(persona.id).length === 0 || name.length === 0) { return; }
    var banner = add(parent, 'section', 'persona-banner');
    var avatar = add(banner, 'div', 'persona-avatar');
    var avatarSrc = text(data.personaAvatarDataUri);
    if (avatarSrc.length > 0) {
      var img = add(avatar, 'img');
      img.src = avatarSrc;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
    } else {
      avatar.textContent = name.slice(0, 1);
    }
    var copy = add(banner, 'div', 'persona-copy');
    add(copy, 'div', 'persona-title', name + '上线');
  }
  app.textContent = '';
  var blocks = list(data.blocks);
  var travelBlocks = blocks.filter(function (block) {
    var kind = text(block && block.kind);
    return kind === 'travel-option' || kind === 'train-option' || kind === 'flight-option';
  });
  var cardBlocks = blocks.filter(function (block) {
    return travelBlocks.indexOf(block) >= 0 || text(block && block.kind) === 'food-result';
  });
  var from = firstMetric(travelBlocks, ['from', 'dep']) || '出发';
  var to = firstMetric(travelBlocks, ['to', 'arr']) || '到达';
  var trainCount = travelBlocks.filter(function (block) { return sourceKind(block) === 'train'; }).length;
  var flightCount = travelBlocks.filter(function (block) { return sourceKind(block) === 'flight'; }).length;
  var queryKind = trainCount > 0 && flightCount === 0 ? '高铁查询' :
    (flightCount > 0 && trainCount === 0 ? '机票查询' : '出行方案');
  var routeHeadline = from !== '出发' && to !== '到达' ? headlinePlace(from) + ' → ' + headlinePlace(to) : (text(data.title) || '今日出行方案');
  var queryHeadline = text(data.subtitle).trim();
  if (queryHeadline.length === 0 || /(?:->|→)/.test(queryHeadline)) { queryHeadline = routeHeadline; }
  var fastest = shortest(travelBlocks);
  var routeSummary = travelBlocks.length > 0 ?
    String(travelBlocks.length) + ' 个方案 · 最快 ' + (fastest || '待确认') :
    (text(data.subtitle) || '等待出行方案返回');
  var shell = add(app, 'main', 'itinerary-shell');
  var hero = add(shell, 'header', 'route-hero');
  var titleRow = add(hero, 'div', 'route-title');
  var titleCopy = add(titleRow, 'div');
  add(titleCopy, 'small', 'route-date', queryKind);
  add(titleCopy, 'h1', '', queryHeadline);
  add(titleCopy, 'p', '', '内容由 AI 生成');
  var dateAction = firstAction(data.actions, 'travel_change_date');
  if (dateAction !== null) {
    var dateButton = add(titleRow, 'button', 'route-date-action');
    dateButton.type = 'button';
    icon(dateButton, 'calendar-days');
    dateButton.setAttribute('aria-label', text(dateAction.label) || '换日期');
    dateButton.disabled = isBusy;
    dateButton.addEventListener('click', function () { postAction(dateAction); });
  }
  renderPersonaBanner(hero);
  var map = add(hero, 'section', 'route-map');
  add(map, 'p', 'route-label', '行程');
  var cities = add(map, 'div', 'route-cities');
  var fromNode = add(cities, 'div', 'route-city');
  add(fromNode, 'b', '', headlinePlace(from));
  add(fromNode, 'span', '', '出发');
  add(cities, 'div', 'route-mid');
  var toNode = add(cities, 'div', 'route-city');
  add(toNode, 'b', '', headlinePlace(to));
  add(toNode, 'span', '', '到达');
  var controls = add(shell, 'nav', 'travel-controls');
  var primaryControls = add(controls, 'div', 'travel-primary-tabs');
  var toolControls = add(controls, 'div', 'travel-tool-row');
  var localControls = [
    { id: 'travel_show_all', label: '全部', prompt: 'travel_show_all', variant: 'secondary', kind: 'client' },
    { id: 'travel_filter_train', label: '高铁', prompt: 'travel_filter_train', variant: 'secondary', kind: 'client' },
    { id: 'travel_filter_flight', label: '飞机', prompt: 'travel_filter_flight', variant: 'secondary', kind: 'client' },
    { id: 'client_sort_fastest', label: '最快', prompt: 'client_sort_fastest', variant: 'secondary', kind: 'client' },
    { id: 'client_filter_available', label: '有票', prompt: 'client_filter_available', variant: 'secondary', kind: 'client' },
    { id: 'client_show_more', label: '更多', prompt: 'client_show_more', variant: 'secondary', kind: 'client' }
  ];
  var seen = {};
  var controlActions = localControls.concat(list(data.actions));
  controlActions.forEach(function (action) {
    var id = text(action && action.id);
    if (id.length === 0 || seen[id]) { return; }
    seen[id] = true;
    var label = text(action && action.label);
    if (id === 'travel_filter_train') { label = '高铁 ' + String(trainCount); }
    if (id === 'travel_filter_flight') { label = '飞机 ' + String(flightCount); }
    if (id === 'client_sort_fastest') { label = '最快'; }
    if (id === 'client_filter_available') { label = '有票'; }
    if (id === 'client_show_more') { label = '更多'; }
    if (id === 'travel_change_date') { label = '换日期'; }
    if (id === 'travel_retry') { label = '重新查询'; }
    var primary = id === 'travel_show_all' || id === 'travel_filter_train' || id === 'travel_filter_flight';
    var button = add(primary ? primaryControls : toolControls, 'button', 'travel-control');
    button.type = 'button';
    button.disabled = isBusy;
    button.setAttribute('data-action', id);
    var controlIconName = controlIcon(id);
    if (controlIconName.length > 0) { icon(button, controlIconName); }
    add(button, 'span', 'travel-control-label', label || id);
    button.addEventListener('click', function () {
      if (handleLocalAction(action)) { return; }
      postAction(action);
    });
  });
  var board = add(shell, 'section', 'journey-board');
  var empty = add(board, 'div', 'journey-empty', '当前筛选下暂无匹配出行方案。');
  empty.id = 'journey-empty';
  empty.style.display = 'none';
  cardBlocks.forEach(function (block, index) {
    var source = sourceKind(block);
    var key = text(block.id) || String(index);
    var selected = text(block.status) === '已选择';
    var cardClass = index === 0 ? 'journey-card featured' : 'journey-card compact';
    if (selected) { cardClass += ' selected'; }
    if (block.calendarConflict === true) { cardClass += ' calendar-conflict'; }
    var card = add(board, 'article', cardClass);
    card.setAttribute('data-card-key', key);
    card.setAttribute('data-source', source);
    card.setAttribute('data-index', String(index));
    card.setAttribute('data-duration', metric(block, ['doorToDoorDuration', 'duration']));
    card.setAttribute('data-availability', [metric(block, ['availability', 'status']), metric(block, ['seats', 'business', 'first', 'second', 'noSeat', 'hardSeat', 'sleeperSoft'])].join(' '));
    card.setAttribute('aria-expanded', 'false');
    var top = add(card, 'div', 'journey-top');
    var title = add(top, 'div', 'journey-title');
    if (source === 'flight') {
      var airlineLogoSrc = airlineLogoUrl(block);
      if (airlineLogoSrc.length > 0) {
        var airlineLogo = add(title, 'img', 'journey-airline-logo');
        airlineLogo.src = airlineLogoSrc;
        airlineLogo.alt = '';
        airlineLogo.setAttribute('aria-hidden', 'true');
      }
      add(title, 'h2', '', [metric(block, ['airline']) || text(block.title), from + ' → ' + to].filter(Boolean).join(' · '));
    } else {
      add(title, 'div', 'journey-tag ' + source, sourceLabel(block));
      add(title, 'h2', '', text(block.title) || text(block.kind) || '出行结果');
    }
    if (selected) { add(title, 'div', 'journey-selected', '已选择'); }
    var expand = add(top, 'button', 'journey-expand', '展开');
    expand.type = 'button';
    icon(expand, 'chevron-down');
    expand.addEventListener('click', function (event) { event.stopPropagation(); setExpanded(key); });
    card.addEventListener('click', function () { setExpanded(key); });
    var mainline = add(card, 'div', 'journey-mainline');
    var left = add(mainline, 'div', 'time-block');
    add(left, 'b', '', displayTime(metric(block, ['depart', 'depTime'])) || '--');
    add(left, 'span', '', metric(block, ['from', 'dep']) || '出发');
    var track = add(mainline, 'div', 'track');
    add(track, 'small', '', metric(block, ['duration']) || '待确认');
    icon(track, source === 'flight' ? 'plane' : 'train-front');
    add(track, 'span', '', source === 'flight' ? '直飞' : '直达');
    var right = add(mainline, 'div', 'time-block');
    add(right, 'b', '', displayTime(metric(block, ['arrive', 'arrTime'])) || '--');
    add(right, 'span', '', metric(block, ['to', 'arr']) || '到达');
    var tripMeta = add(card, 'div', 'journey-trip-meta');
    add(tripMeta, 'span', 'journey-code', text(block.title));
    var availabilityText = metric(block, ['availability', 'status', 'second', 'seats']);
    if (availabilityText.length > 0) {
      add(tripMeta, 'span', 'journey-availability', availabilityText);
    }
    var price = metric(block, ['price']);
    var displayPrice = source === 'flight' ? flightPrice(price) : trainPrice(price);
    if (displayPrice.length > 0) {
      add(tripMeta, 'strong', 'journey-price', displayPrice);
    }
    if (block.calendarConflict === true) {
      var conflictTitle = text(block.calendarConflictTitle);
      var conflict = add(card, 'div', 'journey-conflict');
      icon(conflict, 'calendar-x');
      add(conflict, 'span', '', conflictTitle.length > 0 ?
        '时间冲突 · 与“' + conflictTitle + '”重叠' : '时间冲突 · 与系统日历已有安排重叠');
    }
    var metrics = add(card, 'div', 'journey-metrics');
    var summaryMetrics = [
      ['耗时', metric(block, ['duration']) || '待确认']
    ];
    summaryMetrics.forEach(function (item) {
      var box = add(metrics, 'div', 'journey-metric');
      if (item[0].length > 0) {
        add(box, 'span', '', item[0]);
      }
      add(box, 'b', '', item[1]);
    });
    var expandedGrid = add(card, 'div', 'journey-expanded-grid');
    var expandedItems = [];
    list(block.metrics).concat(list(block.rows)).forEach(function (item) {
      var label = text(item && item.label);
      var value = text(item && item.value);
      if (label.length === 0 || value.length === 0 || label === 'source' || label === 'price') { return; }
      if (expandedItems.length < 3) { expandedItems.push([labelText(label), value]); }
    });
    if (expandedItems.length === 0) {
      expandedItems.push(['来源', sourceLabel(block)]);
    }
    expandedItems.forEach(function (item) {
      var cell = add(expandedGrid, 'span');
      add(cell, 'small', '', item[0]);
      add(cell, 'b', '', item[1]);
    });
    var detail = add(card, 'div', 'journey-detail');
    var grid = add(detail, 'div', 'detail-grid');
    detailRow(grid, '来源', sourceLabel(block));
    list(block.metrics).concat(list(block.rows)).forEach(function (item) {
      if (text(item && item.label) === 'source') { return; }
      if (source === 'train' && text(item && item.label).toLowerCase() === 'price') { return; }
      detailRow(grid, text(item && item.label), text(item && item.value));
    });
    addActionButtons(card, list(block.actions), false);
  });
  applyView();
})();
`;

export function shouldRenderTravelHomeDocument(document: HtmlHomeDocument): boolean {
  if (document.kind !== 'travel') {
    return false;
  }
  const blocks = document.blocks;
  for (let index = 0; index < blocks.length; index++) {
    const kind = blocks[index].kind;
    if (kind === 'travel-option' || kind === 'train-option' || kind === 'flight-option') {
      return true;
    }
  }
  return false;
}

export function renderTravelHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlTravelHomeDocumentWithBusy = {
    version: document.version,
    source: document.source,
    kind: document.kind,
    title: document.title,
    subtitle: document.subtitle,
    chips: document.chips,
    metrics: document.metrics,
    timeline: document.timeline,
    blocks: document.blocks,
    actions: document.actions,
    history: [],
    persona: document.persona,
    personaMemory: document.personaMemory,
    personaAvatarDataUri: personaAvatarDataUri(document.persona.avatarKey),
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlTravelHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : '今日出行方案');
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${TRAVEL_HOME_CSS}</style>
</head>
<body>
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${TRAVEL_HOME_JS}</script>
</body>
</html>`;
}

function escapeScriptJson(json: string): string {
  return json
    .split('&').join('\\u0026')
    .split('<').join('\\u003c')
    .split('>').join('\\u003e')
    .split('\u2028').join('\\u2028')
    .split('\u2029').join('\\u2029');
}

function escapeHtmlText(value: HtmlTravelTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
