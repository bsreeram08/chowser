import { test, expect } from '@playwright/test';

test('picker view loads successfully', async ({ page }) => {
  await page.goto('http://localhost:5173/src/views/picker/index.html');
  await page.waitForLoadState('networkidle');

  await expect(page).toHaveTitle(/Chowser/);
  const body = page.locator('body');
  await expect(body).toBeVisible();
  
  const html = await page.content();
  expect(html.length).toBeGreaterThan(0);
});

test('settings view loads successfully', async ({ page }) => {
  await page.goto('http://localhost:5173/src/views/settings/index.html');
  await page.waitForLoadState('networkidle');

  const body = page.locator('body');
  await expect(body).toBeVisible();
  
  const html = await page.content();
  expect(html.length).toBeGreaterThan(0);
});
