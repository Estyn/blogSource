Write-Host "Building site"
hugo -t estyn
cd public
git add . -A
git commit -m "deploy"
Write-Host "Pushing html"
git push
cd ..
git add . -A
git commit -m "deploy"
Write-Host "Pushing Source"
git push