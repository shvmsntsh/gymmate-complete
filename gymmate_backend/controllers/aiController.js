const axios = require('axios');

const generatePlan = async (req, res) => {
  console.log('Received user data for plan generation:', JSON.stringify(req.body, null, 2));
  const {
    age,
    gender,
    weight,
    height,
    fitnessGoals,
    dietPreferences,
    workoutsPerWeek,
  } = req.body;

  // Basic validation
  if (!age || !gender || !weight || !height || !fitnessGoals || !dietPreferences || !workoutsPerWeek) {
    return res.status(400).json({ message: 'Missing required user data fields.' });
  }

  const prompt = `You are a fitness and nutrition expert. Based on the user's details:
- Age: ${age}, Gender: ${gender}, Weight: ${weight}kg, Height: ${height}cm
- Fitness Goals: ${fitnessGoals.join(', ')}
- Dietary Preference: ${dietPreferences.type}
- Workouts Per Week: ${workoutsPerWeek}

Generate a weekly gym workout plan and a full-day meal plan.
Output ONLY a raw JSON object with two keys: "workoutPlan" and "mealPlan".

- The "workoutPlan" value must be an array of JSON objects, where each object has a "name" (string), "sets" (number), and "reps" (number) key.
- The "mealPlan" value must be an array of JSON objects, where each object has a "name" (e.g., "Breakfast") and a "description" (string) key.

Do not include any other text or formatting.`;

  try {
    const ollamaResponse = await axios.post('http://localhost:11434/api/generate', {
      model: 'gemma:2b',
      prompt: prompt,
      format: 'json',
      stream: false,
    }, {
      timeout: 60000 // 60 second timeout
    });

    const rawResponse = ollamaResponse.data.response;
    console.log('✅ Raw response from Ollama:', rawResponse);

    let plan;
    try {
      plan = JSON.parse(rawResponse);
    } catch (e) {
      console.warn('⚠️ Direct JSON parsing failed. Attempting to extract JSON from the string.');
      const jsonMatch = rawResponse.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        try {
          plan = JSON.parse(jsonMatch[0]);
          console.log('✅ Successfully extracted and parsed JSON.');
        } catch (finalError) {
          console.error('❌ Failed to parse the extracted JSON:', finalError);
          console.error('Problematic extracted string:', jsonMatch[0]);
          throw new Error('Could not parse the JSON response from the AI model.');
        }
      } else {
        console.error('❌ No JSON object found in the AI response.');
        throw new Error('No JSON object could be found in the AI response.');
      }
    }
    
    res.json(plan);
  } catch (error) {
    console.error('Error communicating with Ollama:', error.message);
    res.status(500).json({ message: 'Failed to generate plan from AI model.' });
  }
};

module.exports = { generatePlan }; 