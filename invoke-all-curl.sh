#/bin/bash
URL=https://evo2mods-223863197611.us-central1.run.app
JWT=$(./generate_jwt.sh pentest-sa.json $URL)
echo "JWT=$JWT"
curl -X GET -H "Authorization: Bearer $JWT" $URL
JWT=$(./generate_jwt.sh pentest-sa.json $URL/evo2mod1)
echo "JWT=$JWT"
curl -X POST -H "Authorization: Bearer $JWT" $URL/evo2mod1 -H "Content-Type: application/json" --data '@evo2mod1_inputs.json'
JWT=$(./generate_jwt.sh pentest-sa.json $URL/evo2mod2)
curl -X POST -H "Authorization: Bearer $JWT" $URL/evo2mod2 -H "Content-Type: application/json" --data '@evo2mod2_inputs.json'
JWT=$(./generate_jwt.sh pentest-sa.json $URL/evo2mod3)
curl -X POST -H "Authorization: Bearer $JWT" $URL/evo2mod3 -H "Content-Type: application/json" --data '@evo2mod3_inputs.json'
